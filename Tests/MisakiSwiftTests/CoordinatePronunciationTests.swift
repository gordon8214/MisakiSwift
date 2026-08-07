import Testing
@testable import MisakiSwift

struct CoordinatePronunciationTests {
  @Test func coordinatePronunciationFollowsSentenceContext() {
    let fixtures: [(text: String, expected: String)] = [
      (
        "If decertified, another organization will be appointed to coordinate donations in the region.",
        "kOˈɔɹdənˌAt"
      ),
      ("The GPS coordinate was recorded.", "kOˈɔɹdənət"),
      ("They will coordinate the response.", "kOˈɔɹdənˌAt")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      let tokens = g2p.phonemize(text: fixture.text).1
      let coordinateTokens = tokens.filter { $0.text.lowercased() == "coordinate" }
      #expect(coordinateTokens.count == 1,
              "expected one coordinate token in \(fixture.text.debugDescription)")
      #expect(coordinateTokens.first?.phonemes == fixture.expected,
              "wrong coordinate pronunciation in \(fixture.text.debugDescription)")
    }
  }
}
