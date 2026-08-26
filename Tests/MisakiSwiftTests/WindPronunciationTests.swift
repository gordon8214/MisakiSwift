import Testing
@testable import MisakiSwift

struct WindPronunciationTests {
  @Test func windPronunciationFollowsMeasuredContext() throws {
    let fixtures: [(text: String, word: String, expected: String)] = [
      (
        "People have deep, generational ties to this part of the state, where the "
          + "normally peaceful river winds through limestone under majestic cypress trees.",
        "winds",
        "wˈIndz"
      ),
      ("The path winds across the field.", "winds", "wˈIndz"),
      ("The stream winds toward the sea.", "winds", "wˈIndz"),
      ("Strong winds through the valley battered homes.", "winds", "wˈɪndz"),
      ("The winds through the valley battered homes.", "winds", "wˈɪndz"),
      ("A winding road crossed the hills.", "winding", "wˈIndɪŋ")
    ]
    let processors = [
      try EnglishG2P(british: false, requireRemoteFrontendParity: true),
      try EnglishG2P(british: true, requireRemoteFrontendParity: true)
    ]

    for processor in processors {
      for fixture in fixtures {
        let tokens = processor.phonemize(text: fixture.text).1
        let matchingTokens = tokens.filter { $0.text.lowercased() == fixture.word }
        #expect(matchingTokens.count == 1,
                "expected one \(fixture.word) token in \(fixture.text.debugDescription)")
        #expect(matchingTokens.first?.phonemes == fixture.expected,
                "wrong \(fixture.word) pronunciation in \(fixture.text.debugDescription)")
      }
    }
  }
}
