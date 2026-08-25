import Testing
@testable import MisakiSwift

struct LeadPronunciationTests {
  private static let reportedSentence =
    "Per the authors, the mummification process throughout history has relied on various toxic "
    + "materials and substances to help preserve the remains—heavy metals like arsenic, mercury, "
    + "and lead, for example—which is why careful handling is necessary to avoid adverse health effects."

  @Test func leadPronunciationFollowsMaterialContext() throws {
    let materialContexts = [
      Self.reportedSentence,
      "The crew removed lead paint.",
      "The pipe was made of lead.",
      "The sample contains lead.",
      "The label named the heavy metal lead.",
      "The alloy contained copper, iron, and lead.",
      "Tests found lead in the drinking water.",
      "Tests found lead in soil.",
      "The contamination came from lead from old pipes.",
      "Workers removed lead-based paint.",
      "Tests measured arsenic, mercury, lead."
    ]
    let otherContexts = [
      "They will lead the team.",
      "Take the lead.",
      "The lead author spoke.",
      "The sales lead called.",
      "The dog was on a lead.",
      "Mercury spilled. And lead the team away.",
      "Heavy metals lead to poisoning.",
      "They lead paint-removal projects.",
      "Study arsenic and mercury, and lead the discussion.",
      "Review mercury – and lead the discussion.",
      "Review mercury - and lead the discussion.",
      "Review mercury -- and lead the discussion.",
      "She has the lead in the race.",
      "They lead from the front."
    ]

    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      let guideReading = british ? "lˈiːd" : "lˈid"

      for text in materialContexts {
        #expect(
          leadPhoneme(in: text, using: g2p) == "lˈɛd",
          "wrong material reading in \(text)"
        )
      }
      for text in otherContexts {
        #expect(
          leadPhoneme(in: text, using: g2p) == guideReading,
          "wrong guide/leader reading in \(text)"
        )
      }
    }
  }

  private func leadPhoneme(in text: String, using g2p: EnglishG2P) -> String? {
    let tokens = g2p.phonemize(text: text).1
    return tokens.first { $0.text.lowercased() == "lead" }?.phonemes
  }
}
