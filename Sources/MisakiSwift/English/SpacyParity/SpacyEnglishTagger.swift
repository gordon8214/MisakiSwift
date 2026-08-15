import Foundation
import NaturalLanguage

public struct EnglishFrontendToken: Equatable, Sendable {
  public let text: String
  public let whitespace: String
  public let pennTag: String

  public init(text: String, whitespace: String, pennTag: String) {
    self.text = text
    self.whitespace = whitespace
    self.pennTag = pennTag
  }
}

struct SpacyTaggerTrace {
  let tokens: [SpacyTokenizedWord]
  let features: [[UInt64]]
  let vectors: [[Float]]
  let pennTags: [String]
}

final class SpacyEnglishTagger {
  private struct Configuration: Decodable {
    struct Feature: Decodable {
      let name: String
      let rows: Int
      let seed: UInt32
    }

    let version: String
    let features: [Feature]
    let width: Int
    let window: Int
    let depth: Int
    let maxoutPieces: Int
    let labels: [String]
    let stringIDs: [String: UInt64]

    enum CodingKeys: String, CodingKey {
      case version
      case features
      case width
      case window
      case depth
      case maxoutPieces = "maxout_pieces"
      case labels
      case stringIDs = "string_ids"
    }
  }

  /// One residual `maxout` + `layer_norm` pair from the tok2vec encoder.
  private struct Block {
    let maxout: SpacyMaxoutLayer
    let layerNorm: LayerNormLayer
  }

  /// Rows each feature contributes per token, summed — spaCy's `HashEmbed`
  /// hashes every attribute into four buckets.
  private static let hashKeysPerFeature = 4

  /// thinc's `LayerNorm` epsilon, which is not PyTorch's 1e-5. The BART
  /// fallback uses the other one, so the value has to travel with the caller.
  private static let layerNormEpsilon = 1e-8

  private let tokenizer: SpacyTokenizer
  private let configuration: Configuration
  /// `[featureIndex][row * width + column]`, in feature order.
  private let embeddings: [[Float]]
  private let embedProjection: SpacyMaxoutLayer
  private let embedLayerNorm: LayerNormLayer
  private let blocks: [Block]
  private let tagger: LinearLayer

  init() throws {
    tokenizer = try SpacyTokenizer()
    guard let metadataURL = Bundle.module.url(forResource: "spacy_tagger", withExtension: "json"),
          let weightsURL = Bundle.module.url(forResource: "spacy_tagger", withExtension: "safetensors") else {
      throw SpacyParityError.missingResource("spacy_tagger")
    }
    let file: SafetensorsFile
    do {
      configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(contentsOf: metadataURL)
      )
      file = try SafetensorsFile(contentsOf: weightsURL)
    } catch let error as SpacyParityError {
      throw error
    } catch {
      throw SpacyParityError.invalidResource("spacy_tagger")
    }
    guard configuration.version == SpacyTokenizer.modelVersion,
          configuration.width == 96,
          configuration.window == 1,
          configuration.depth == 4,
          configuration.maxoutPieces == 3,
          configuration.features.count == 6 else {
      throw SpacyParityError.unsupportedModel(configuration.version)
    }

    func tensor(_ name: String) throws -> SafetensorsFile.Tensor {
      guard let value = file.tensors[name] else {
        throw SpacyParityError.invalidResource("spacy_tagger (missing weight '\(name)')")
      }
      return value
    }

    // Each table is `[feature.rows, width]`; a disagreement here would land as
    // an out-of-range gather rather than a wrong answer, so check it once.
    var tables: [[Float]] = []
    tables.reserveCapacity(configuration.features.count)
    for (index, feature) in configuration.features.enumerated() {
      let table = try tensor("embed.\(index).E")
      guard table.shape == [feature.rows, configuration.width] else {
        throw SpacyParityError.invalidResource(
          "spacy_tagger (embed.\(index).E is \(table.shape), expected [\(feature.rows), \(configuration.width)])"
        )
      }
      tables.append(table.values)
    }
    embeddings = tables

    embedProjection = try SpacyMaxoutLayer(
      weight: tensor("embed_projection.W"), bias: tensor("embed_projection.b")
    )
    embedLayerNorm = try LayerNormLayer(
      gain: tensor("embed_layer_norm.G"), bias: tensor("embed_layer_norm.b"),
      epsilon: Self.layerNormEpsilon
    )
    blocks = try (0..<configuration.depth).map { index in
      Block(
        maxout: try SpacyMaxoutLayer(
          weight: tensor("block.\(index).maxout.W"), bias: tensor("block.\(index).maxout.b")
        ),
        layerNorm: try LayerNormLayer(
          gain: tensor("block.\(index).layer_norm.G"), bias: tensor("block.\(index).layer_norm.b"),
          epsilon: Self.layerNormEpsilon
        )
      )
    }
    tagger = try LinearLayer(weight: tensor("tagger.W"), bias: tensor("tagger.b"))
    guard tagger.bias?.count == configuration.labels.count else {
      throw SpacyParityError.invalidResource("spacy_tagger (tagger head does not match the labels)")
    }
  }

  func frontendTokens(for text: String) -> [EnglishFrontendToken] {
    let trace = trace(text)
    return zip(trace.tokens, trace.pennTags).map { token, pennTag in
      EnglishFrontendToken(text: token.text, whitespace: token.whitespace, pennTag: pennTag)
    }
  }

  func trace(_ text: String) -> SpacyTaggerTrace {
    let tokens = tokenizer.tokenize(text)
    guard !tokens.isEmpty else {
      return SpacyTaggerTrace(tokens: [], features: [], vectors: [], pennTags: [])
    }

    let features = tokens.map(featureValues)

    // Hash embed: each of the six attributes is hashed into four buckets whose
    // rows are summed, and the six results are joined side by side into one
    // `features.count * width` row per token.
    var encoded = FloatMatrix(rows: tokens.count, columns: 0, values: [])
    for featureIndex in configuration.features.indices {
      let feature = configuration.features[featureIndex]
      var indexes: [Int] = []
      indexes.reserveCapacity(tokens.count * Self.hashKeysPerFeature)
      for row in features {
        for key in Self.hashEmbedKeys(row[featureIndex], seed: feature.seed) {
          indexes.append(Int(UInt64(key) % UInt64(feature.rows)))
        }
      }
      encoded = MatrixMath.horizontallyConcatenated(
        encoded,
        MatrixMath.summedEmbeddingRows(
          table: embeddings[featureIndex],
          width: configuration.width,
          indexes: indexes,
          keysPerRow: Self.hashKeysPerFeature
        )
      )
    }

    encoded = embedLayerNorm(embedProjection(encoded))

    // Residual window blocks. The padding is what lets a token near either end
    // still see a full receptive field; it is stripped again below.
    let receptiveField = configuration.window * configuration.depth
    var contextual = MatrixMath.verticallyPadded(encoded, by: receptiveField)
    for block in blocks {
      let update = block.layerNorm(block.maxout(MatrixMath.windowExpanded(contextual)))
      MatrixMath.add(&contextual, update)
    }
    encoded = contextual.rowRange(receptiveField..<(receptiveField + tokens.count))

    let tags = MatrixMath.argmaxPerRow(tagger(encoded)).map { configuration.labels[$0] }
    return SpacyTaggerTrace(
      tokens: tokens, features: features, vectors: encoded.rowArrays(), pennTags: tags
    )
  }

  private func featureValues(_ token: SpacyTokenizedWord) -> [UInt64] {
    [
      SpacyStringStore.id(for: token.normalized, reserved: configuration.stringIDs),
      SpacyStringStore.id(for: Self.firstUnicodeScalar(token.text), reserved: configuration.stringIDs),
      SpacyStringStore.id(for: Self.lastUnicodeScalars(token.text, count: 3), reserved: configuration.stringIDs),
      SpacyStringStore.id(for: Self.wordShape(token.text), reserved: configuration.stringIDs),
      token.hasFollowingSpace ? 1 : 0,
      token.isSpace ? 1 : 0
    ]
  }

  private static func firstUnicodeScalar(_ text: String) -> String {
    text.unicodeScalars.first.map(String.init) ?? ""
  }

  private static func lastUnicodeScalars(_ text: String, count: Int) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.suffix(count)))
  }

  private static func wordShape(_ text: String) -> String {
    guard text.unicodeScalars.count < 100 else {
      return "LONG"
    }
    var output = ""
    var previous = ""
    var repetition = 0
    for scalar in text.unicodeScalars {
      let value: String
      if scalar.properties.isAlphabetic {
        value = scalar.properties.isUppercase ? "X" : "x"
      } else if scalar.properties.numericType != nil {
        value = "d"
      } else {
        value = String(scalar)
      }
      if value == previous {
        repetition += 1
      } else {
        repetition = 0
        previous = value
      }
      if repetition < 4 {
        output += value
      }
    }
    return output
  }

  private static func hashEmbedKeys(_ value: UInt64, seed: UInt32) -> [UInt32] {
    var first = value
    first = first &* 0x87c37b91114253d5
    first = (first << 31) | (first >> 33)
    first = first &* 0x4cf5ad432745937f
    first ^= UInt64(seed)
    first ^= 8
    var second = UInt64(seed)
    second ^= 8
    first = first &+ second
    second = second &+ first
    first = mixHash(first)
    second = mixHash(second)
    first = first &+ second
    second = second &+ first
    return [
      UInt32(truncatingIfNeeded: first),
      UInt32(truncatingIfNeeded: first >> 32),
      UInt32(truncatingIfNeeded: second),
      UInt32(truncatingIfNeeded: second >> 32)
    ]
  }

  private static func mixHash(_ input: UInt64) -> UInt64 {
    var value = input
    value ^= value >> 33
    value = value &* 0xff51afd7ed558ccd
    value ^= value >> 33
    value = value &* 0xc4ceb9fe1a85ec53
    value ^= value >> 33
    return value
  }
}

extension SpacyEnglishTagger {
  static func lexicalClass(for pennTag: String) -> NLTag? {
    switch pennTag {
    case "$", "ADD", "FW", "LS", "SYM", "XX": .otherWord
    case "''": .closeQuote
    case ",", ".", ":", "NFP": .punctuation
    case "-LRB-": .openParenthesis
    case "-RRB-": .closeParenthesis
    case "AFX", "JJ", "JJR", "JJS": .adjective
    case "CC": .conjunction
    case "CD": .number
    case "DT", "PDT", "WDT": .determiner
    case "EX", "PRP", "PRP$", "WP", "WP$": .pronoun
    case "HYPH": .dash
    case "IN": .preposition
    case "MD", "VB", "VBD", "VBG", "VBN", "VBP", "VBZ": .verb
    case "NN", "NNS": .noun
    case "NNP", "NNPS": .personalName
    case "POS", "RP": .particle
    case "RB", "RBR", "RBS", "WRB": .adverb
    case "TO": .preposition
    case "UH": .interjection
    case "_SP": .whitespace
    case "``": .openQuote
    default: nil
    }
  }
}
