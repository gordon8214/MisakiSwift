import Testing
@testable import MisakiSwift

struct LivePronunciationTests {
  @Test func livePronunciationFollowsSentenceContext() {
    let fixtures: [(text: String, expected: String)] = [
      ("You may also get a reprieve if you have an older device that doesn't meet " +
       "Gemini's minimum specifications or if you live in a region where Gemini is not supported.",
       "lˈɪv"),
      ("Watch the live video.", "lˈIv"),
      ("The event is live now.", "lˈIv")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      let tokens = g2p.phonemize(text: fixture.text).1
      let liveTokens = tokens.filter { $0.text.lowercased() == "live" }
      #expect(liveTokens.count == 1, "expected one live token in \(fixture.text.debugDescription)")
      #expect(liveTokens.first?.phonemes == fixture.expected,
              "wrong live pronunciation in \(fixture.text.debugDescription)")
    }
  }
}
