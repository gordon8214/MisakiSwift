import Foundation
import MLX
import MLXNN
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

  private let tokenizer: SpacyTokenizer
  private let configuration: Configuration
  private let weights: [String: MLXArray]

  init() throws {
    tokenizer = try SpacyTokenizer()
    guard let metadataURL = Bundle.module.url(forResource: "spacy_tagger", withExtension: "json"),
          let weightsURL = Bundle.module.url(forResource: "spacy_tagger", withExtension: "safetensors") else {
      throw SpacyParityError.missingResource("spacy_tagger")
    }
    do {
      configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(contentsOf: metadataURL)
      )
      weights = try MLX.loadArrays(url: weightsURL)
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
    var embedded: [MLXArray] = []
    embedded.reserveCapacity(configuration.features.count)
    for featureIndex in configuration.features.indices {
      let feature = configuration.features[featureIndex]
      var indexes: [Int32] = []
      indexes.reserveCapacity(tokens.count * 4)
      for row in features {
        for key in Self.hashEmbedKeys(row[featureIndex], seed: feature.seed) {
          indexes.append(Int32(UInt64(key) % UInt64(feature.rows)))
        }
      }
      let indexArray = MLXArray(indexes)
      let table = Embedding(weight: requiredWeight("embed.\(featureIndex).E"))
      let vectors = table(indexArray)
        .reshaped([tokens.count, 4, configuration.width])
        .sum(axis: 1)
      embedded.append(vectors)
    }

    var encoded = concatenated(embedded, axis: 1)
    encoded = maxout(
      encoded,
      weight: requiredWeight("embed_projection.W"),
      bias: requiredWeight("embed_projection.b")
    )
    encoded = layerNormalize(
      encoded,
      gain: requiredWeight("embed_layer_norm.G"),
      bias: requiredWeight("embed_layer_norm.b")
    )

    let receptiveField = configuration.window * configuration.depth
    let padding = MLXArray.zeros([receptiveField, configuration.width])
    var contextual = concatenated([padding, encoded, padding], axis: 0)
    for blockIndex in 0..<configuration.depth {
      let expanded = expandWindow(contextual)
      var update = maxout(
        expanded,
        weight: requiredWeight("block.\(blockIndex).maxout.W"),
        bias: requiredWeight("block.\(blockIndex).maxout.b")
      )
      update = layerNormalize(
        update,
        gain: requiredWeight("block.\(blockIndex).layer_norm.G"),
        bias: requiredWeight("block.\(blockIndex).layer_norm.b")
      )
      contextual = contextual + update
    }
    encoded = contextual[receptiveField..<(receptiveField + tokens.count)]

    let logits = Linear(
      weight: requiredWeight("tagger.W"),
      bias: requiredWeight("tagger.b")
    )(encoded)
    let tagIndexes = logits.argMax(axis: 1).asArray(Int32.self)
    let tags = tagIndexes.map { configuration.labels[Int($0)] }
    let vectors = encoded.asArray(Float.self).chunked(width: configuration.width)
    return SpacyTaggerTrace(tokens: tokens, features: features, vectors: vectors, pennTags: tags)
  }

  private func requiredWeight(_ name: String) -> MLXArray {
    guard let weight = weights[name] else {
      preconditionFailure("Missing spaCy tagger weight: \(name)")
    }
    return weight
  }

  private func maxout(_ input: MLXArray, weight: MLXArray, bias: MLXArray) -> MLXArray {
    let outputWidth = weight.dim(0)
    let pieces = weight.dim(1)
    let inputWidth = weight.dim(2)
    let flattenedWeight = weight.reshaped([outputWidth * pieces, inputWidth])
    let flattenedBias = bias.reshaped([outputWidth * pieces])
    return Linear(weight: flattenedWeight, bias: flattenedBias)(input)
      .reshaped([input.dim(0), outputWidth, pieces])
      .max(axis: 2)
  }

  private func layerNormalize(_ input: MLXArray, gain: MLXArray, bias: MLXArray) -> MLXArray {
    let mean = input.mean(axis: 1, keepDims: true)
    let variance = input.variance(axis: 1, keepDims: true) + 1e-8
    return (input - mean) * variance.rsqrt() * gain + bias
  }

  private func expandWindow(_ input: MLXArray) -> MLXArray {
    let padding = MLXArray.zeros([1, input.dim(1)])
    let padded = concatenated([padding, input, padding], axis: 0)
    let count = input.dim(0)
    return concatenated(
      [padded[0..<count], padded[1..<(count + 1)], padded[2..<(count + 2)]],
      axis: 1
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

private extension Array {
  func chunked(width: Int) -> [[Element]] {
    guard width > 0 else {
      return []
    }
    return stride(from: 0, to: count, by: width).map { start in
      Array(self[start..<Swift.min(start + width, count)])
    }
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
