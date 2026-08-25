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
        nextWord: context.next,
        adjacentWord: context.next
      ) == .verb)
    }
  }

  /// Both tags asserted here select the lexicon's DEFAULT entry: ADJ has no
  /// entry of its own for "live" and falls through to it, so what this pins is
  /// that neither context reaches the VERB entry.
  ///
  /// `adjacentWord` is passed exactly as `resolve` computes it. Leaving it to
  /// its default had this asserting `.otherWord` for "the video" — a state
  /// `resolve` cannot produce, since it would supply the right context and get
  /// the attributive override.
  @Test func liveNonVerbContextsKeepTheDefaultReading() {
    let contexts: [(previous: String, next: String, expected: NLTag)] = [
      ("the", "video", .adjective),
      ("is", "now", .otherWord),
      ("you", "broadcast", .adjective)
    ]

    for context in contexts {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "live",
        currentTag: .otherWord,
        previousWord: context.previous,
        nextWord: context.next,
        adjacentWord: context.next
      ) == context.expected)
    }
  }

  /// The attributive list must never admit a word that can follow the VERB.
  /// "I live round the corner" is ordinary British English for "around", and
  /// "round" sat in that list until it was measured flipping six such
  /// sentences — so this pins the SHAPE of that mistake rather than one word,
  /// and goes red the moment anything preposition-like is added.
  @Test func liveKeepsTheVerbReadingBeforeAPrepositionalRightContext() {
    let rightContexts = [
      "round", "near", "nearby", "here", "there", "in", "on", "by", "with",
      "beside", "outside", "abroad", "alone", "together"
    ]

    for rightContext in rightContexts {
      #expect(EnglishHeteronymResolver.resolvedTag(
        for: "live",
        currentTag: .verb,
        previousWord: "they",
        nextWord: rightContext,
        adjacentWord: rightContext
      ) == .verb, "\(rightContext) reached the attributive list")
    }
  }

  /// The reported failure. en_core_web_sm reads the coordination in "…data
  /// from the Environmental Protection Agency and live birth records" as a
  /// second verb phrase and tags "live" VERB outright, so the fallback above —
  /// which only fires on an unusable tag — never saw it and the lexicon's VERB
  /// entry said "live your life". An attributive noun outranks the tag.
  @Test func liveUsesTheAdjectiveReadingBeforeAnAttributiveNoun() {
    let sourceTags: [NLTag?] = [nil, .otherWord, .verb, .noun, .adjective]

    for sourceTag in sourceTags {
      for rightContext in ["birth", "births", "streaming", "videos"] {
        #expect(EnglishHeteronymResolver.resolvedTag(
          for: "live",
          currentTag: sourceTag,
          previousWord: "and",
          nextWord: rightContext,
          adjacentWord: rightContext
        ) == .adjective, "\(rightContext) did not override \(String(describing: sourceTag))")
      }
    }
  }

  /// The override reads the IMMEDIATELY adjacent token, so it cannot reach
  /// across a sentence boundary. `nextWord` skips punctuation, which would
  /// otherwise let "Long may you live. Music played." find a right context in
  /// the next sentence and unsay a correctly tagged verb.
  @Test func liveAttributiveOverrideDoesNotCrossPunctuation() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "live",
      currentTag: .verb,
      previousWord: "you",
      nextWord: "music",
      adjacentWord: nil
    ) == .verb)
  }

  @Test func liveFallbackDoesNotReplaceAUsablePOSTag() {
    #expect(EnglishHeteronymResolver.resolvedTag(
      for: "live",
      currentTag: .adjective,
      previousWord: "you",
      nextWord: "in"
    ) == .adjective)
  }

  @Test func leadUsesTheLedAliasOnlyWithMaterialEvidence() {
    let materialContexts: [(previous: String?, beforePrevious: String?, adjacent: String?)] = [
      (nil, nil, "paint"),
      ("metal", "heavy", nil),
      ("contains", "sample", nil),
      ("of", "made", nil),
      ("and", "mercury", nil)
    ]

    for context in materialContexts {
      #expect(EnglishHeteronymResolver.resolvedAlias(
        for: "lead",
        previousWord: context.previous,
        wordBeforePrevious: context.beforePrevious,
        adjacentWord: context.adjacent
      ) == "led")
    }
  }

  @Test func leadKeepsItsSpellingForGuideAndLeaderSenses() {
    let otherContexts: [(previous: String?, beforePrevious: String?, adjacent: String?)] = [
      ("will", "they", "the"),
      ("the", "take", nil),
      ("the", nil, "author"),
      ("sales", "the", nil),
      ("a", "on", nil),
      ("contains", "book", "stories")
    ]

    for context in otherContexts {
      #expect(EnglishHeteronymResolver.resolvedAlias(
        for: "lead",
        previousWord: context.previous,
        wordBeforePrevious: context.beforePrevious,
        adjacentWord: context.adjacent
      ) == nil)
    }
  }
}
