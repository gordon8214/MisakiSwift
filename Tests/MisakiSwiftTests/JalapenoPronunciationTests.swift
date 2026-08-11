import Testing
@testable import MisakiSwift

struct JalapenoPronunciationTests {
  private static let fixtures: [(british: Bool, singular: String, plural: String)] = [
    (false, "ʤˌæləpˈinjO", "ʤˌæləpˈinjOz"),
    (true, "ʤˌaləpˈiːnjQ", "ʤˌaləpˈiːnjQz")
  ]

  @Test func enyeIsPreservedInSingularAndPluralForms() throws {
    for fixture in Self.fixtures {
      let g2p = try EnglishG2P(
        british: fixture.british,
        requireRemoteFrontendParity: true
      )
      let forms = [
        ("jalapeño", fixture.singular),
        ("jalapeños", fixture.plural),
        ("Jalapeños", fixture.plural),
        ("jalapen\u{303}os", fixture.plural)
      ]

      for (text, expected) in forms {
        let actual = g2p.phonemize(text: text).0
        #expect(
          actual == expected,
          "wrong jalapeño pronunciation for \(text.debugDescription): \(actual)"
        )
      }
    }
  }
}
