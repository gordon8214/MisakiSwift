import Testing
@testable import MisakiSwift

struct ContentPronunciationTests {
  @Test func contentPronunciationFollowsSentenceContext() {
    let fixtures: [(text: String, expected: String)] = [
      ("Today's blog post further claimed that Old Reddit is leading to unwarranted content scraping.",
       "kˈɑntɛnt"),
      ("I feel content.", "kəntˈɛnt")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      let tokens = g2p.phonemize(text: fixture.text).1
      let contentTokens = tokens.filter { $0.text.lowercased() == "content" }
      #expect(contentTokens.count == 1,
              "expected one content token in \(fixture.text.debugDescription)")
      #expect(contentTokens.first?.phonemes == fixture.expected,
              "wrong content pronunciation in \(fixture.text.debugDescription)")
    }
  }
}
