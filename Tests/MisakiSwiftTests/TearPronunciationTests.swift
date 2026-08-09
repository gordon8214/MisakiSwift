import Testing
@testable import MisakiSwift

struct TearPronunciationTests {
  @Test func tearPronunciationFollowsPhraseContext() {
    let fixtures: [(text: String, expected: String)] = [
      (
        "So for Perseverance, the wheels were redesigned, and there are no signs of appreciable wear and tear, Lee said.",
        "tˈɛɹ"
      ),
      ("The tear drops fell from her eyes.", "tˈɪɹ"),
      ("Do not tear the paper.", "tˈɛɹ")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      let tokens = g2p.phonemize(text: fixture.text).1
      let tearTokens = tokens.filter { $0.text.lowercased() == "tear" }
      #expect(tearTokens.count == 1,
              "expected one tear token in \(fixture.text.debugDescription)")
      #expect(tearTokens.first?.phonemes == fixture.expected,
              "wrong tear pronunciation in \(fixture.text.debugDescription)")
    }
  }
}
