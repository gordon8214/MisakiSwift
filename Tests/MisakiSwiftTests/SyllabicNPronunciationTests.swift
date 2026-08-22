import Testing
@testable import MisakiSwift

struct SyllabicNPronunciationTests {
  @Test func americanGlottalStopBeforeSyllabicNEmitsAnExplicitVowel() throws {
    let g2p = try EnglishG2P(british: false, requireRemoteFrontendParity: true)
    let fixtures = [
      ("Manhattan", "mænhˈætᵊn"),
      ("Manhattans", "mænhˈætᵊnz"),
      ("button", "bˈʌtᵊn"),
      ("buttoned", "bˈʌtᵊnd"),
      ("certain", "sˈɜɹtᵊn"),
      ("eaten", "ˈitᵊn"),
      ("flattening", "flˈætᵊnɪŋ"),
      ("kitten", "kˈɪtᵊn")
    ]

    for (text, expected) in fixtures {
      #expect(g2p.phonemize(text: text).0 == expected)
    }
  }

  @Test func britishExplicitSyllablesStayUnchanged() throws {
    let g2p = try EnglishG2P(british: true, requireRemoteFrontendParity: true)
    #expect(g2p.phonemize(text: "Manhattan").0 == "manhˈatᵊn")
    #expect(g2p.phonemize(text: "button").0 == "bˈʌtᵊn")
    #expect(g2p.phonemize(text: "eaten").0 == "ˈiːtᵊn")
    #expect(g2p.phonemize(text: "kitten").0 == "kˈɪtᵊn")
  }
}
