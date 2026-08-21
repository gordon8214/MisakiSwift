import Testing
@testable import MisakiSwift

struct FiancePronunciationTests {
  private static let fixtures: [(british: Bool, singular: String, plural: String)] = [
    (false, "fiˈɑnsA", "fiˈɑnsAz"),
    (true, "fiˈɒnsA", "fiˈɒnsAz")
  ]

  @Test func accentedSpellingsUseTheFiancingLexiconStem() throws {
    for fixture in Self.fixtures {
      let g2p = try EnglishG2P(
        british: fixture.british,
        requireRemoteFrontendParity: true
      )
      let forms = [
        ("fiancé", fixture.singular),
        ("Fiancé", fixture.singular),
        ("FIANCÉ", fixture.singular),
        ("fiance\u{301}", fixture.singular),
        ("fiancée", fixture.singular),
        ("Fiancée", fixture.singular),
        ("FIANCÉE", fixture.singular),
        ("fiance\u{301}e", fixture.singular),
        ("fiancés", fixture.plural),
        ("fiancées", fixture.plural),
        ("fiancé's", fixture.plural),
        ("fiancée's", fixture.plural)
      ]

      for (text, expected) in forms {
        let actual = g2p.phonemize(text: text).0
        #expect(
          actual == expected,
          "wrong fiancé pronunciation for \(text.debugDescription): \(actual)"
        )
      }
    }
  }
}
