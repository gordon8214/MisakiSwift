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

  @Test func nasaPossessiveKeepsTheBaseAcronymReading() throws {
    let g2p = try EnglishG2P(requireRemoteFrontendParity: true)
    let expected = "nˈæsəz nˈuᵻst ɹˈOvəɹ ɪz ɹˈɛdi."

    for apostrophe in ["'", "’"] {
      let text = "NASA\(apostrophe)s newest rover is ready."
      let (phonemes, tokens) = g2p.phonemize(text: text)
      let nasa = try #require(tokens.first { $0.text.hasPrefix("NASA") })

      #expect(nasa.phonemes == "nˈæsəz")
      #expect(phonemes == expected)
    }
  }

  @Test func letterSpelledPossessiveRemainsLetterSpelled() throws {
    let g2p = try EnglishG2P(requireRemoteFrontendParity: true)
    let (phonemes, tokens) = g2p.phonemize(text: "FBI's newest report is ready.")
    let fbi = try #require(tokens.first { $0.text == "FBI's" })

    #expect(fbi.phonemes == "ˌɛfbˌiˈIz")
    #expect(phonemes == "ˌɛfbˌiˈIz nˈuᵻst ɹəpˈɔɹt ɪz ɹˈɛdi.")
  }
}
