import Testing
@testable import MisakiSwift

struct USPlaceNamePronunciationTests {
  private static let fixtures: [(text: String, expected: String)] = [
    ("Los Angeles", "lˈɔs ˈænʤələs"),
    ("Las Vegas", "lˈɑs vˈAɡəs"),
    ("San Diego", "sˈæn diˈAɡO"),
    ("San Jose", "sˈæn hˌOzˈA"),
    ("San Juan", "sˈæn wˈɑn"),
    ("San Antonio", "sˈæn æntˈOnˌiO"),
    ("El Paso", "ˌɛl pˈæsO")
  ]

  @Test func placeNamesUseTheirNorthAmericanEnglishPronunciations() throws {
    let g2p = try EnglishG2P(british: false, requireRemoteFrontendParity: true)

    for fixture in Self.fixtures {
      for text in [fixture.text, fixture.text.lowercased()] {
        let actual = g2p.phonemize(text: text).0
        #expect(
          actual == fixture.expected,
          "wrong place-name pronunciation for \(text.debugDescription): \(actual)"
        )
      }
    }
  }
}
