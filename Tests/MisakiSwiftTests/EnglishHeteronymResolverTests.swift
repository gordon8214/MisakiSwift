import NaturalLanguage
import Testing
@testable import MisakiSwift

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

@Test func liveMediaContextsKeepTheDefaultReading() {
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
