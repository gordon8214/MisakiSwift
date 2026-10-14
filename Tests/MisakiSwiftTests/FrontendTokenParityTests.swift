import Foundation
import Testing
@testable import MisakiSwift

@Suite struct FrontendTokenParityTests {
  private struct Snapshot: Decodable {
    let text: String
    let british: Bool
    let phonemes: String
    let tokens: [String]
  }

  // Recorded with the previous frontend before moving MToken out of MLXUtilsLibrary.
  @Test(arguments: [false, true]) func matchesPreviousFrontend(british: Bool) throws {
    let url = try #require(Bundle.module.url(forResource: "frontend_token_parity", withExtension: "json"))
    let snapshots = try JSONDecoder().decode([Snapshot].self, from: Data(contentsOf: url))
    let processor = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
    for snapshot in snapshots where snapshot.british == british {
      let result = processor.phonemize(text: snapshot.text)
      #expect(result.0 == snapshot.phonemes, "Phonemes changed for: \(snapshot.text)")
      #expect(result.1.map { String(describing: $0) } == snapshot.tokens,
              "Token metadata changed for: \(snapshot.text)")
    }
  }

  @Test func copyingTokenPreservesIndependentMetadata() {
    let text = "copied"
    let original = MToken(text: text, tokenRange: text.startIndex..<text.endIndex,
                          whitespace: " ", phonemes: "kˈɑpid")
    original.`_`.alias = "copy"
    original.`_`.stress = 1
    original.`_`.rating = 4
    let copy = MToken(copying: original)
    #expect(String(describing: copy) == String(describing: original))
    copy.`_`.alias = "changed"
    #expect(original.`_`.alias == "copy")
    #expect(copy !== original)
    #expect(copy.`_` !== original.`_`)
  }
}
