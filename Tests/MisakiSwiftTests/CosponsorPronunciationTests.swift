import Testing
@testable import MisakiSwift

struct CosponsorPronunciationTests {
  @Test func cosponsorFamilyMatchesItsHyphenatedReading() throws {
    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      for ending in ["", "s", "ed", "ing", "ship", "ships", "'s"] {
        let word = "cosponsor" + ending
        let expected = g2p.phonemize(text: "co-sponsor" + ending).0
        for spelling in [word, word.capitalized, word.uppercased()] {
          #expect(g2p.phonemize(text: spelling).0 == expected, "\(spelling), british=\(british)")
        }
      }
      let expected = british ? "kˌQspˈɒnsəɹɪŋ" : "kˌOspˈɑnsəɹɪŋ"
      #expect(g2p.phonemize(text: "They are cosponsoring the bill.").0.contains(expected))
      #expect(g2p.phonemize(text: "sponsoring").0 == (british ? "spˈɒnsəɹɪŋ" : "spˈɑnsəɹɪŋ"))
      #expect(g2p.phonemize(text: "cost").0 == (british ? "kˈɒst" : "kˈɔst"))
    }
  }
}
