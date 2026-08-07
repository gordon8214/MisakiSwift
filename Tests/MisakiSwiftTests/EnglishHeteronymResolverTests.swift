import NaturalLanguage
import Testing
@testable import MisakiSwift

struct EnglishHeteronymResolverTests {
  @Test func coordinateUsesTheVerbReadingAfterAnInfinitiveOrModal() {
    let contexts = ["to", "can", "could", "may", "might", "must", "shall", "should", "will", "would"]

    for previousWord in contexts {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "coordinate",
        currentTag: .noun,
        previousWord: previousWord,
        nextWord: "donations"
      ) == .verb)
    }
  }

  @Test func coordinateKeepsNominalAndAdjectivalReadings() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "coordinate",
      currentTag: .noun,
      previousWord: "GPS",
      nextWord: nil
    ) == .noun)
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "coordinate",
      currentTag: .adjective,
      previousWord: nil,
      nextWord: "system"
    ) == .adjective)
  }

  @Test func contentUsesTheNounReadingBeforeScraping() {
    let sourceTags: [NLTag?] = [nil, .otherWord, .adjective, .noun]

    for sourceTag in sourceTags {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "content",
        currentTag: sourceTag,
        previousWord: "unwarranted",
        nextWord: "scraping"
      ) == .noun)
    }
  }

  @Test func contentUsesTheAdjectiveReadingAfterALinkingVerb() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "content",
      currentTag: .noun,
      previousWord: "feel",
      nextWord: nil
    ) == .adjective)
  }

  @Test func contentFallbackLeavesOtherContextsUntouched() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "content",
      currentTag: .adjective,
      previousWord: "a",
      nextWord: "child"
    ) == .adjective)
  }

  @Test func liveUsesTheVerbReadingWhenPOSTaggingIsUnavailable() {
    let contexts: [(previous: String, next: String)] = [
      ("you", "in"),
      ("we", "here"),
      ("who", "nearby"),
      ("to", "forever"),
      ("can", "longer")
    ]

    for context in contexts {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "live",
        currentTag: .otherWord,
        previousWord: context.previous,
        nextWord: context.next
      ) == .verb)
    }
  }

  @Test func liveNonVerbContextsKeepTheDefaultReading() {
    let contexts: [(previous: String, next: String)] = [
      ("the", "video"),
      ("is", "now"),
      ("you", "broadcast")
    ]

    for context in contexts {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "live",
        currentTag: .otherWord,
        previousWord: context.previous,
        nextWord: context.next
      ) == .otherWord)
    }
  }

  @Test func liveFallbackDoesNotReplaceAUsablePOSTag() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "live",
      currentTag: .adjective,
      previousWord: "you",
      nextWord: "in"
    ) == .adjective)
  }
}
