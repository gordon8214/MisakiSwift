import MLXUtilsLibrary
import NaturalLanguage

enum EnglishHeteronymResolver {
  // Some iOS NaturalLanguage runtimes return `.otherWord` for "live" even in
  // an unambiguous verb phrase. Apply this fallback only when POS tagging gave
  // us no usable answer; a real lexical tag remains authoritative.
  private static let liveVerbLeftContexts: Set<String> = [
    "i", "you", "we", "they", "who",
    "to", "can", "could", "may", "might", "must", "shall", "should", "will", "would",
    "do", "does", "did", "don't", "doesn't", "didn't"
  ]

  // Nouns "live" can only be modifying attributively. Unlike the fallback
  // above this list OVERRIDES the tag, because en_core_web_sm reads a
  // coordination such as "air pollution data from the agency and live birth
  // records" as a second verb phrase and tags "live" VERB with no hedging —
  // which picks the lexicon's VERB entry and says "live your life". Deferring
  // to the tag costs nothing here: the /laɪv/ reading is right for every word
  // in this list whatever the grammar turns out to be, since even a genuinely
  // verbal "live blog" or "live stream" is said that way.
  //
  // Matched against the IMMEDIATELY adjacent token, never `nextWord`, which
  // skips punctuation: "Long may you live. Music played." would otherwise find
  // a right context in the following sentence and unsay the verb.
  //
  // Inflections are listed explicitly rather than stemmed, because the two
  // forms are not always both safe: "rounds" is here and "round" deliberately
  // is NOT, since "I live round the corner" is ordinary British English for
  // "around" and the tagger reads it correctly without help. A word earns a
  // place here only if no sentence puts it directly after the verb.
  private static let liveAttributiveRightContexts: Set<String> = [
    // Broadcast and performance
    "album", "albums", "audience", "audiences", "audio", "blog", "blogs",
    "broadcast", "broadcasts", "chat", "chats", "concert", "concerts",
    "coverage", "demo", "demos", "event", "events", "feed", "feeds",
    "footage", "music", "performance", "performances", "podcast", "podcasts",
    "radio", "recording", "recordings", "session", "sessions", "show", "shows",
    "stream", "streaming", "streams", "television", "tv", "video", "videos",
    // Biology and medicine
    "animal", "animals", "attenuated", "bacteria", "birth", "births", "cattle",
    "cell", "cells", "culture", "cultures", "organism", "organisms", "poultry",
    "specimen", "specimens", "tissue", "tissues", "vaccine", "vaccines",
    "virus", "viruses", "yeast",
    // Ordnance and electricity
    "ammo", "ammunition", "fire", "grenade", "grenades", "rounds",
    "wire", "wires",
    // The tree
    "oak", "oaks"
  ]

  // Apple's lexical tagger is inconsistent for both senses of "content": on
  // macOS it tags the predicate in "feel content" as a noun, while the iOS
  // runtime has tagged the noun adjunct in "content scraping" as an adjective.
  // These two unambiguous local contexts let us choose the heteronym without
  // trusting either platform's tag. Keep the noun rule deliberately narrow so
  // a genuinely adjectival phrase such as "a content child" stays untouched.
  private static let contentAdjectiveLeftContexts: Set<String> = [
    "am", "are", "be", "became", "become", "been", "being", "feel", "feeling",
    "feels", "felt", "is", "remain", "remained", "remaining", "remains", "seem",
    "seemed", "seeming", "seems", "was", "were"
  ]

  private static let contentNounRightContexts: Set<String> = [
    "scraper", "scrapers", "scraping"
  ]

  // The iOS lexical tagger can call the infinitive in "to coordinate
  // donations" a noun, selecting the noun/adjective reading ending in
  // /-nət/ instead of the verb reading ending in /-neɪt/. A preceding
  // infinitive marker or modal is stronger evidence than that tag. Limit the
  // correction to those contexts so nominal and adjectival uses such as
  // "GPS coordinate" and "coordinate system" retain the default reading.
  private static let coordinateVerbLeftContexts: Set<String> = [
    "to", "can", "could", "may", "might", "must", "shall", "should", "will", "would"
  ]

  // The gold lexicon stores the /tɛɹ/ reading of "tear" under VERB and
  // uses the /tɪɹ/ teardrop reading as DEFAULT. In the fixed expression
  // "wear and tear", however, "tear" is grammatically a noun, so even an
  // accurate tag selects the wrong entry. Match the complete local expression
  // before borrowing the verb tag solely to select the intended phonemes.
  private static let wearAndTearLeftContext = ("wear", "and")

  // en_core_web_sm still labels an uppercase letter as DT in a few compact
  // noun labels (notably "Hepatitis A vaccine"). These heads are positive
  // evidence for a letter name; ordinary sentence-initial and mid-sentence
  // articles remain untouched.
  private static let letterNameLeftContexts: Set<String> = [
    "answer", "appendix", "choice", "class", "exhibit", "grade", "group",
    "hepatitis", "option", "plan", "section", "team", "type", "vitamin"
  ]

  static func resolve(tokens: [MToken], pennTags: inout PennTagMap) {
    for (index, token) in tokens.enumerated() where token.phonemes == nil {
      let previousWords = tokens[..<index].reversed().compactMap(normalizedWord)
      let previousWord = previousWords.first
      let wordBeforePrevious = previousWords.dropFirst().first
      let nextWord = tokens.dropFirst(index + 1).compactMap(normalizedWord).first
      // The first token that is not whitespace. spaCy folds a single trailing
      // space into `MToken.whitespace` but emits a longer run as its own `_SP`
      // token, and a double space between a word and its noun is not a
      // boundary — skipping it cannot reopen the punctuation hole below,
      // because punctuation is a token `normalizedWord` still rejects.
      let adjacentWord = tokens
        .dropFirst(index + 1)
        .first { !$0.text.allSatisfy(\.isWhitespace) }
        .flatMap(normalizedWord)
      if token.text == "A",
         pennTags[ObjectIdentifier(token)] == "DT",
         let previousWord,
         letterNameLeftContexts.contains(previousWord) {
        token.tag = .noun
        pennTags[ObjectIdentifier(token)] = "NN"
        continue
      }
      let originalTag = token.tag
      let tag = resolvedTag(
        for: token.text,
        currentTag: originalTag,
        previousWord: previousWord,
        nextWord: nextWord,
        wordBeforePrevious: wordBeforePrevious,
        adjacentWord: adjacentWord
      )
      token.tag = tag
      guard tag != originalTag else {
        continue
      }
      switch tag {
      case .verb:
        pennTags[ObjectIdentifier(token)] = "VB"
      case .adjective:
        pennTags[ObjectIdentifier(token)] = "JJ"
      case .noun:
        pennTags[ObjectIdentifier(token)] = "NN"
      default:
        break
      }
    }
  }

  static func resolvedTag(
    for word: String,
    currentTag: NLTag?,
    previousWord: String?,
    nextWord: String?,
    wordBeforePrevious: String? = nil,
    adjacentWord: String? = nil
  ) -> NLTag? {
    switch word.lowercased() {
    case "coordinate":
      if let previousWord, coordinateVerbLeftContexts.contains(previousWord) {
        return .verb
      }
      return currentTag
    case "content":
      if let nextWord, contentNounRightContexts.contains(nextWord) {
        return .noun
      }
      if let previousWord, contentAdjectiveLeftContexts.contains(previousWord) {
        return .adjective
      }
      return currentTag
    case "live":
      if let adjacentWord, liveAttributiveRightContexts.contains(adjacentWord) {
        return .adjective
      }
      guard currentTag == nil || currentTag == .otherWord else {
        return currentTag
      }
      // No `nextWord` branch here. Declining the fallback on a right context
      // used to be this case's job, and the override above now does it
      // strictly better: `adjacentWord` is nil exactly when the right context
      // lies past a non-letter token, so a `nextWord` test could only ever
      // fire ACROSS punctuation — unsaying the verb in "…where they live.
      // Coverage of the storm continues." That is the hole the override was
      // written to avoid, so the branch is gone rather than widened.
      if let previousWord, liveVerbLeftContexts.contains(previousWord) {
        return .verb
      }
      return currentTag
    case "tear":
      if (wordBeforePrevious, previousWord) == wearAndTearLeftContext {
        return .verb
      }
      return currentTag
    default:
      return currentTag
    }
  }

  private static func normalizedWord(_ token: MToken) -> String? {
    guard token.text.contains(where: \.isLetter) else { return nil }
    return token.text.lowercased()
  }
}
