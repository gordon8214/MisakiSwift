import Testing
@testable import MisakiSwift

struct NinoPronunciationTests {
  private static let fixtures: [(british: Bool, word: String, phrase: String)] = [
    (false, "nˈinjO", "ˌɛl nˈinjO"),
    (true, "nˈiːnjQ", "ˌɛl nˈiːnjQ")
  ]

  @Test func enyeAndInitialVowelArePreserved() throws {
    for fixture in Self.fixtures {
      let g2p = try EnglishG2P(
        british: fixture.british,
        requireRemoteFrontendParity: true
      )

      for text in ["niño", "Niño", "nin\u{303}o"] {
        let actual = g2p.phonemize(text: text).0
        #expect(
          actual == fixture.word,
          "wrong niño pronunciation for \(text.debugDescription): \(actual)"
        )
      }

      let phrase = g2p.phonemize(text: "El Niño").0
      #expect(phrase == fixture.phrase, "wrong El Niño pronunciation: \(phrase)")
    }
  }
}
