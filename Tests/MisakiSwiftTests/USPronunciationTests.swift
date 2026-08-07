import Testing
@testable import MisakiSwift

struct USPronunciationTests {
  @Test func geographicUSUsesTheDeployedProperNounReadingWithoutTextRewrites() throws {
    let g2p = try EnglishG2P(requireRemoteFrontendParity: true)
    let (phonemes, tokens) = g2p.phonemize(text: "The US health department.")
    let us = try #require(tokens.first { $0.text == "US" })

    #expect(us.phonemes == "jˌuˈɛs")
    #expect(phonemes == "ðə jˌuˈɛs hˈɛlθ dəpˈɑɹtmənt.")
  }
}
