import Foundation
import Testing
@testable import MisakiSwift

@Suite(.serialized)
struct SpacyFrontendParityTests {
  private struct Fixture: Decodable {
    struct Record: Decodable {
      struct Token: Decodable {
        let text: String
        let whitespace: String
        let norm: String
        let prefix: String
        let suffix: String
        let shape: String
        let isSpace: Bool
        let tag: String

        enum CodingKeys: String, CodingKey {
          case text
          case whitespace
          case norm
          case prefix
          case suffix
          case shape
          case isSpace = "is_space"
          case tag
        }
      }

      let text: String
      let tokens: [Token]
      let features: [[UInt64]]
      let tok2vec: [[Float]]
    }

    let version: String
    let records: [Record]
  }

  @Test
  func tokenizerFeaturesVectorsAndPennTagsMatchDeployedSpacy() throws {
    let fixture = try loadFixture()
    #expect(fixture.version == SpacyTokenizer.modelVersion)
    let tagger = try SpacyEnglishTagger()

    for record in fixture.records {
      let actual = tagger.trace(record.text)
      #expect(actual.tokens.map(\.text) == record.tokens.map(\.text), "Token text: \(record.text)")
      #expect(actual.tokens.map(\.whitespace) == record.tokens.map(\.whitespace), "Whitespace: \(record.text)")
      #expect(actual.tokens.map(\.normalized) == record.tokens.map(\.norm), "Norm: \(record.text)")
      #expect(actual.tokens.map(\.isSpace) == record.tokens.map(\.isSpace), "IS_SPACE: \(record.text)")
      #expect(actual.features == record.features, "Hashed attributes: \(record.text)")
      #expect(actual.pennTags == record.tokens.map(\.tag), "Penn tags: \(record.text)")
      #expect(actual.vectors.count == record.tok2vec.count)
      for (actualRow, expectedRow) in zip(actual.vectors, record.tok2vec) {
        #expect(actualRow.count == expectedRow.count)
        let maximumError = zip(actualRow, expectedRow).map { abs($0 - $1) }.max() ?? 0
        #expect(maximumError < 0.000_1, "tok2vec max error \(maximumError): \(record.text)")
      }
    }
  }

  private func loadFixture() throws -> Fixture {
    guard let url = Bundle.module.url(forResource: "spacy_parity_trace", withExtension: "json") else {
      throw SpacyParityError.missingResource("spacy_parity_trace.json")
    }
    return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
  }
}
