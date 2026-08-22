import Testing
@testable import MisakiSwift

struct SupplementalCommonNounPronunciationTests {
  @Test func naiveUsesTheExistingAsciiGoldReading() throws {
    let fixtures: [(british: Bool, singular: String, plural: String)] = [
      (false, "nɑˈiv", "nɑˈivz"),
      (true, "nIˈiːv", "nIˈiːvz")
    ]

    for fixture in fixtures {
      let g2p = try EnglishG2P(british: fixture.british, requireRemoteFrontendParity: true)
      let forms = [
        ("naïve", fixture.singular),
        ("Naïve", fixture.singular),
        ("NAÏVE", fixture.singular),
        ("nai\u{308}ve", fixture.singular),
        ("naïve's", fixture.plural),
        ("naïves", fixture.plural)
      ]

      for (text, expected) in forms {
        #expect(g2p.phonemize(text: text).0 == expected)
      }
    }
  }

  @Test func robotaxiUsesTheTaxiCompoundRatherThanScientificTaxis() throws {
    let fixtures: [(
      british: Bool,
      singular: String,
      possessive: String,
      plural: String,
      scientific: String
    )] = [
      (false, "ɹˌObətˈæksi", "ɹˌObətˈæksiz", "ɹˌObətˈæksiz", "kˌimOtˈæksɪs"),
      (true, "ɹˌQbətˈaksi", "ɹˌQbətˈaksiz", "ɹˌQbətˈaksiːz", "kˌiːmQtˈaksɪs")
    ]

    for fixture in fixtures {
      let g2p = try EnglishG2P(british: fixture.british, requireRemoteFrontendParity: true)
      for text in ["robotaxi", "Robotaxi", "ROBOTAXI"] {
        #expect(g2p.phonemize(text: text).0 == fixture.singular)
      }
      #expect(g2p.phonemize(text: "robotaxi's").0 == fixture.possessive)
      for text in ["robotaxis", "Robotaxis", "ROBOTAXIS"] {
        #expect(g2p.phonemize(text: text).0 == fixture.plural)
      }
      #expect(g2p.phonemize(text: "chemotaxis").0 == fixture.scientific)
    }
  }
}
