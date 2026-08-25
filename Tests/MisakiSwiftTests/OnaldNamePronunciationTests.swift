import Testing
@testable import MisakiSwift

struct OnaldNamePronunciationTests {
  @Test func onaldNamesReuseTheGoldMcDonaldVowel() throws {
    let fixtures: [(british: Bool, donald: String, ronald: String, mcDonald: String)] = [
      (false, "dˈɑnəld", "ɹˈɑnəld", "məkdˈɑnəld"),
      (true, "dˈɒnᵊld", "ɹˈɒnᵊld", "məkdˈɒnᵊld")
    ]

    for fixture in fixtures {
      let g2p = try EnglishG2P(
        british: fixture.british,
        requireRemoteFrontendParity: true
      )
      for spelling in ["donald", "Donald", "DONALD"] {
        #expect(g2p.phonemize(text: spelling).0 == fixture.donald)
      }
      #expect(g2p.phonemize(text: "Donald's").0 == fixture.donald + "z")
      #expect(g2p.phonemize(text: "Donalds").0 == fixture.donald + "z")

      for spelling in ["ronald", "Ronald", "RONALD"] {
        #expect(g2p.phonemize(text: spelling).0 == fixture.ronald)
      }
      #expect(g2p.phonemize(text: "Ronald's").0 == fixture.ronald + "z")
      #expect(g2p.phonemize(text: "Ronalds").0 == fixture.ronald + "z")
      #expect(g2p.phonemize(text: "McDonald").0 == fixture.mcDonald)
    }
  }
}
