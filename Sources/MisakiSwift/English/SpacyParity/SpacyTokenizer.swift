import Foundation

struct SpacyTokenizedWord: Equatable {
  let text: String
  let range: Range<String.Index>
  let whitespace: String
  let normalized: String
  let isSpace: Bool

  var hasFollowingSpace: Bool {
    whitespace == " "
  }
}

enum SpacyParityError: LocalizedError {
  case missingResource(String)
  case invalidResource(String)
  case unsupportedModel(String)

  var errorDescription: String? {
    switch self {
    case .missingResource(let name):
      "Missing spaCy parity resource: \(name)"
    case .invalidResource(let name):
      "Invalid spaCy parity resource: \(name)"
    case .unsupportedModel(let version):
      "Unsupported spaCy parity model: \(version)"
    }
  }
}

final class SpacyTokenizer {
  private struct Configuration: Decodable {
    struct SpecialCase: Decodable {
      let orth: String
      let norm: String?
    }

    let version: String
    let prefix: String
    let suffix: String
    let infix: String
    let url: String
    let specialCases: [String: [SpecialCase]]
    let normExceptions: [String: String]
    let baseNorms: [String: String]
    let stringIDs: [String: UInt64]

    enum CodingKeys: String, CodingKey {
      case version
      case prefix
      case suffix
      case infix
      case url
      case specialCases = "special_cases"
      case normExceptions = "norm_exceptions"
      case baseNorms = "base_norms"
      case stringIDs = "string_ids"
    }
  }

  private struct Piece {
    let text: String
    let range: Range<String.Index>
    let norm: String?
  }

  static let modelVersion = "en_core_web_sm-3.8.0"

  private let prefixExpression: NSRegularExpression
  private let suffixExpression: NSRegularExpression
  private let infixExpression: NSRegularExpression
  private let urlExpression: NSRegularExpression
  private let specialCases: [String: [Configuration.SpecialCase]]
  private let normExceptions: [String: String]
  private let baseNorms: [String: String]
  private let stringIDs: [String: UInt64]

  init() throws {
    guard let url = Bundle.module.url(forResource: "spacy_tokenizer", withExtension: "json") else {
      throw SpacyParityError.missingResource("spacy_tokenizer.json")
    }
    let configuration: Configuration
    do {
      configuration = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
    } catch {
      throw SpacyParityError.invalidResource("spacy_tokenizer.json")
    }
    guard configuration.version == Self.modelVersion else {
      throw SpacyParityError.unsupportedModel(configuration.version)
    }
    do {
      prefixExpression = try NSRegularExpression(pattern: configuration.prefix)
      suffixExpression = try NSRegularExpression(pattern: configuration.suffix)
      infixExpression = try NSRegularExpression(pattern: configuration.infix)
      urlExpression = try NSRegularExpression(pattern: configuration.url)
    } catch {
      throw SpacyParityError.invalidResource("spacy_tokenizer.json regex")
    }
    specialCases = configuration.specialCases
    normExceptions = configuration.normExceptions
    baseNorms = configuration.baseNorms
    stringIDs = configuration.stringIDs
  }

  func tokenize(_ text: String) -> [SpacyTokenizedWord] {
    guard !text.isEmpty else {
      return []
    }

    var pieces: [Piece] = []
    var spanStart = text.startIndex
    var spanIsWhitespace = text[spanStart].isWhitespace
    var index = spanStart

    while index < text.endIndex {
      let next = text.index(after: index)
      let isWhitespace = text[index].isWhitespace
      if isWhitespace != spanIsWhitespace {
        appendOuterSpan(
          text: text,
          range: spanStart..<index,
          followingCharacter: text[index],
          pieces: &pieces
        )
        if text[index] == " " {
          if !pieces.isEmpty {
            let previous = pieces.removeLast()
            pieces.append(Piece(text: previous.text, range: previous.range, norm: previous.norm))
          }
          spanStart = next
        } else {
          spanStart = index
        }
        spanIsWhitespace.toggle()
      }
      index = next
    }

    if spanStart < text.endIndex {
      appendOuterSpan(text: text, range: spanStart..<text.endIndex, followingCharacter: nil, pieces: &pieces)
    }

    // `_tokenize_affixes` stores a single ASCII space as the SPACY flag on
    // the preceding token. Reconstruct that flag from the source boundaries;
    // all other whitespace remains a token in its own right.
    var result: [SpacyTokenizedWord] = []
    for (pieceIndex, piece) in pieces.enumerated() {
      let trailingSpace: String
      if piece.range.upperBound < text.endIndex,
         text[piece.range.upperBound] == " ",
         pieceIndex + 1 == pieces.count || pieces[pieceIndex + 1].range.lowerBound != piece.range.upperBound {
        trailingSpace = " "
      } else if piece.range.upperBound == text.endIndex,
                text.last == " ",
                !piece.text.allSatisfy(\.isWhitespace) {
        trailingSpace = " "
      } else {
        trailingSpace = ""
      }
      result.append(
        SpacyTokenizedWord(
          text: piece.text,
          range: piece.range,
          whitespace: trailingSpace,
          normalized: normalized(piece),
          isSpace: piece.text.allSatisfy(\.isWhitespace)
        )
      )
    }
    return result
  }

  private func normalized(_ piece: Piece) -> String {
    if let norm = piece.norm {
      return norm
    }
    if let norm = baseNorms[piece.text] {
      return norm
    }
    let orth = SpacyStringStore.id(for: piece.text, reserved: stringIDs)
    return normExceptions[String(orth)] ?? piece.text.lowercased()
  }

  private func appendOuterSpan(
    text: String,
    range: Range<String.Index>,
    followingCharacter: Character?,
    pieces: inout [Piece]
  ) {
    guard !range.isEmpty else {
      return
    }
    let span = String(text[range])
    if span == " " && followingCharacter != nil {
      pieces.append(Piece(text: span, range: range, norm: nil))
      return
    }
    pieces.append(contentsOf: splitAffixes(text: text, range: range))
  }

  private func splitAffixes(text: String, range: Range<String.Index>) -> [Piece] {
    let source = String(text[range])
    if let special = specialCases[source] {
      return specialPieces(special, text: text, range: range)
    }

    var core = range
    var prefixes: [Piece] = []
    var suffixes: [Piece] = []
    var lastScalarCount = -1

    while !core.isEmpty {
      let coreText = String(text[core])
      let scalarCount = coreText.unicodeScalars.count
      guard scalarCount != lastScalarCount else {
        break
      }
      if specialCases[coreText] != nil {
        break
      }
      lastScalarCount = scalarCount

      let prefixRange = firstMatch(prefixExpression, in: coreText)
      let prefixLength = prefixRange?.length ?? 0
      let suffixSearchText = prefixLength == 0
        ? coreText
        : String(coreText.dropFirst(prefixRange.map { unicodeScalarCount(in: coreText, utf16Range: $0) } ?? 0))
      let suffixRange = firstMatch(suffixExpression, in: suffixSearchText)
      let prefixScalars = prefixRange.map { unicodeScalarCount(in: coreText, utf16Range: $0) } ?? 0
      let suffixScalars = suffixRange.map { unicodeScalarCount(in: suffixSearchText, utf16Range: $0) } ?? 0

      if prefixScalars > 0 {
        let prefixEnd = index(in: text, from: core.lowerBound, scalarOffset: prefixScalars)
        let remaining = prefixEnd..<core.upperBound
        if !remaining.isEmpty, specialCases[String(text[remaining])] != nil {
          prefixes.append(Piece(text: String(text[core.lowerBound..<prefixEnd]), range: core.lowerBound..<prefixEnd, norm: nil))
          core = remaining
          break
        }
      }

      if suffixScalars > 0 {
        let suffixStart = index(in: text, from: core.upperBound, scalarOffset: -suffixScalars)
        let remaining = core.lowerBound..<suffixStart
        if !remaining.isEmpty, specialCases[String(text[remaining])] != nil {
          suffixes.append(Piece(text: String(text[suffixStart..<core.upperBound]), range: suffixStart..<core.upperBound, norm: nil))
          core = remaining
          break
        }
      }

      if prefixScalars > 0, suffixScalars > 0, prefixScalars + suffixScalars <= scalarCount {
        let prefixEnd = index(in: text, from: core.lowerBound, scalarOffset: prefixScalars)
        let suffixStart = index(in: text, from: core.upperBound, scalarOffset: -suffixScalars)
        prefixes.append(Piece(text: String(text[core.lowerBound..<prefixEnd]), range: core.lowerBound..<prefixEnd, norm: nil))
        suffixes.append(Piece(text: String(text[suffixStart..<core.upperBound]), range: suffixStart..<core.upperBound, norm: nil))
        core = prefixEnd..<suffixStart
      } else if prefixScalars > 0 {
        let prefixEnd = index(in: text, from: core.lowerBound, scalarOffset: prefixScalars)
        prefixes.append(Piece(text: String(text[core.lowerBound..<prefixEnd]), range: core.lowerBound..<prefixEnd, norm: nil))
        core = prefixEnd..<core.upperBound
      } else if suffixScalars > 0 {
        let suffixStart = index(in: text, from: core.upperBound, scalarOffset: -suffixScalars)
        suffixes.append(Piece(text: String(text[suffixStart..<core.upperBound]), range: suffixStart..<core.upperBound, norm: nil))
        core = core.lowerBound..<suffixStart
      }
    }

    var output = prefixes
    if !core.isEmpty {
      let coreText = String(text[core])
      if let special = specialCases[coreText] {
        output.append(contentsOf: specialPieces(special, text: text, range: core))
      } else if isFullMatch(urlExpression, text: coreText) {
        output.append(Piece(text: coreText, range: core, norm: nil))
      } else {
        output.append(contentsOf: splitInfixes(text: text, range: core))
      }
    }
    output.append(contentsOf: suffixes.reversed())
    return output
  }

  private func splitInfixes(text: String, range: Range<String.Index>) -> [Piece] {
    let source = String(text[range])
    let matches = infixExpression.matches(
      in: source,
      range: NSRange(source.startIndex..<source.endIndex, in: source)
    )
    guard !matches.isEmpty else {
      return [Piece(text: source, range: range, norm: nil)]
    }

    var result: [Piece] = []
    var localStart = source.startIndex
    let firstStart = Range(matches[0].range, in: source)?.lowerBound
    for match in matches {
      guard let localRange = Range(match.range, in: source), localRange.lowerBound != firstStart || localRange.lowerBound != localStart else {
        continue
      }
      if localRange.lowerBound != localStart {
        result.append(piece(from: localStart..<localRange.lowerBound, source: source, text: text, outerStart: range.lowerBound))
      }
      if !localRange.isEmpty {
        result.append(piece(from: localRange, source: source, text: text, outerStart: range.lowerBound))
      }
      localStart = localRange.upperBound
    }
    if localStart < source.endIndex {
      result.append(piece(from: localStart..<source.endIndex, source: source, text: text, outerStart: range.lowerBound))
    }
    return result
  }

  private func specialPieces(
    _ special: [Configuration.SpecialCase],
    text: String,
    range: Range<String.Index>
  ) -> [Piece] {
    var cursor = range.lowerBound
    return special.compactMap { item in
      let end = index(in: text, from: cursor, scalarOffset: item.orth.unicodeScalars.count)
      guard end <= range.upperBound else {
        return nil
      }
      defer { cursor = end }
      return Piece(text: item.orth, range: cursor..<end, norm: item.norm)
    }
  }

  private func piece(
    from localRange: Range<String.Index>,
    source: String,
    text: String,
    outerStart: String.Index
  ) -> Piece {
    let startOffset = source.unicodeScalars.distance(from: source.unicodeScalars.startIndex, to: localRange.lowerBound)
    let length = source.unicodeScalars.distance(from: localRange.lowerBound, to: localRange.upperBound)
    let start = index(in: text, from: outerStart, scalarOffset: startOffset)
    let end = index(in: text, from: start, scalarOffset: length)
    return Piece(text: String(source[localRange]), range: start..<end, norm: nil)
  }

  private func firstMatch(_ expression: NSRegularExpression, in text: String) -> NSRange? {
    expression.firstMatch(
      in: text,
      range: NSRange(text.startIndex..<text.endIndex, in: text)
    )?.range
  }

  private func isFullMatch(_ expression: NSRegularExpression, text: String) -> Bool {
    let full = NSRange(text.startIndex..<text.endIndex, in: text)
    return expression.firstMatch(in: text, range: full)?.range == full
  }

  private func unicodeScalarCount(in text: String, utf16Range: NSRange) -> Int {
    guard let range = Range(utf16Range, in: text) else {
      return 0
    }
    return text.unicodeScalars.distance(from: range.lowerBound, to: range.upperBound)
  }

  private func index(in text: String, from start: String.Index, scalarOffset: Int) -> String.Index {
    text.unicodeScalars.index(start, offsetBy: scalarOffset)
  }
}
