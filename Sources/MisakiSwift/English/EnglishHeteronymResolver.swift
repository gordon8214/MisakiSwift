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

  // Gold carries both senses of `winds`, but the spaCy tagger sometimes calls
  // the third-person verb a plural noun when a path-like subject moves through
  // space. The reported long sentence tagged `river winds through` as NNS and
  // selected wˈɪndz; shorter variants were inconsistent (`path winds across`
  // and `stream winds toward` failed, while `road winds through` worked).
  // Require positive evidence on BOTH sides instead of overriding every NNS:
  // weather phrases such as `strong winds through the valley` have the same
  // right context and must keep the DEFAULT reading.
  private static let windingPathLeftContexts: Set<String> = [
    "path", "river", "road", "stream", "trail"
  ]

  private static let windingMotionRightContexts: Set<String> = [
    "across", "along", "around", "through", "toward"
  ]

  // The gold lexicon stores the /tɛɹ/ reading of "tear" under VERB and
  // uses the /tɪɹ/ teardrop reading as DEFAULT. In the fixed expression
  // "wear and tear", however, "tear" is grammatically a noun, so even an
  // accurate tag selects the wrong entry. Match the complete local expression
  // before borrowing the verb tag solely to select the intended phonemes.
  private static let wearAndTearLeftContext = ("wear", "and")

  // Gold `lead` has only the guide/leader reading, while gold `led` is the
  // metal vowel in both dialects. POS cannot distinguish those noun senses,
  // so use the token alias seam for positive lexical evidence of the element.
  // The surface token remains `lead`; only its dictionary lookup becomes
  // `led`, which derives the dialect-safe phonemes instead of duplicating IPA.
  private static let leadMetalRightContexts: Set<String> = [
    "acid", "alloy", "alloys", "battery", "batteries", "bullet", "bullets",
    "concentration", "concentrations", "contamination", "dust", "exposure",
    "glaze", "ingot", "ingots", "level", "levels", "metal", "ore", "oxide",
    "paint", "pipe", "pipes", "poisoning", "shot", "smelter", "smelting",
    "solder", "toxicity"
  ]

  private static let leadMetalImmediateLeftContexts: Set<String> = [
    "element", "elements", "metal", "metals"
  ]

  private static let leadMetalTerminalObjectLeftContexts: Set<String> = [
    "contain", "contained", "containing", "contains", "detect", "detected",
    "detecting", "detects"
  ]

  private static let leadMetalTwoWordLeftContexts: Set<String> = [
    "concentration of", "exposure to", "levels of", "made from", "made of",
    "poisoning from", "traces of"
  ]

  private static let leadMetalListPeers: Set<String> = [
    "arsenic", "cadmium", "copper", "gold", "iron", "mercury", "nickel",
    "silver", "tin", "zinc"
  ]

  private static let leadMetalInMaterials: Set<String> = [
    "blood", "soil", "water"
  ]

  private static let leadMetalFromSources: Set<String> = [
    "paint", "paints", "pipe", "pipes"
  ]

  private static let contextBoundaryCharacters: Set<Character> = Set(".!?;:—–")

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
      let previousWords = precedingClauseWords(tokens, before: index)
      let previousWord = previousWords.first
      let wordBeforePrevious = previousWords.dropFirst().first
      let followingWords = followingClauseWords(tokens, after: index)
      let nextWord = tokens.dropFirst(index + 1).compactMap(normalizedWord).first
      // Unlike `previousWord`, this cannot cross punctuation. The winding
      // heuristic needs evidence immediately beside `winds`; the broader scan
      // remains intentional for lead/tear contexts such as comma-separated
      // material lists.
      let precedingAdjacentWord = tokens[..<index]
        .reversed()
        .first { !$0.text.allSatisfy(\.isWhitespace) }
        .flatMap(normalizedWord)
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
      if let alias = resolvedAlias(
        for: token.text,
        currentTag: token.tag,
        pennTag: pennTags[ObjectIdentifier(token)],
        previousWord: previousWord,
        wordBeforePrevious: wordBeforePrevious,
        adjacentWord: adjacentWord,
        followingWords: followingWords,
        isHyphenatedToFollowingWord: isHyphenatedToFollowingWord(tokens, at: index)
      ) {
        token.`_`.alias = alias
        continue
      }
      let originalTag = token.tag
      let tag = resolvedTag(
        for: token.text,
        currentTag: originalTag,
        previousWord: previousWord,
        nextWord: nextWord,
        wordBeforePrevious: wordBeforePrevious,
        precedingAdjacentWord: precedingAdjacentWord,
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
    precedingAdjacentWord: String? = nil,
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
    case "winds":
      if let precedingAdjacentWord,
         let adjacentWord,
         windingPathLeftContexts.contains(precedingAdjacentWord),
         windingMotionRightContexts.contains(adjacentWord) {
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

  static func resolvedAlias(
    for word: String,
    currentTag: NLTag? = nil,
    pennTag: String? = nil,
    previousWord: String?,
    wordBeforePrevious: String?,
    adjacentWord: String?,
    followingWords: [String] = [],
    isHyphenatedToFollowingWord: Bool = false
  ) -> String? {
    guard word.lowercased() == "lead" else { return nil }

    let hasListEvidence: Bool
    if let previousWord, let wordBeforePrevious {
      hasListEvidence = ((previousWord == "and" || previousWord == "or")
        && leadMetalListPeers.contains(wordBeforePrevious))
        || (leadMetalListPeers.contains(previousWord)
          && leadMetalListPeers.contains(wordBeforePrevious))
    } else {
      hasListEvidence = false
    }
    let endsMaterialList = adjacentWord == nil
      && (followingWords.isEmpty || Array(followingWords.prefix(2)) == ["for", "example"])
    let hasUsableVerbTag = currentTag == .verb || (pennTag?.hasPrefix("VB") ?? false)
    guard !hasUsableVerbTag || (hasListEvidence && endsMaterialList) else { return nil }

    if let adjacentWord, leadMetalRightContexts.contains(adjacentWord) {
      return "led"
    }
    if isHyphenatedToFollowingWord, followingWords.first == "based" {
      return "led"
    }
    if let preposition = followingWords.first {
      let boundedObjects = followingWords.dropFirst().prefix(3)
      if preposition == "in", !leadMetalInMaterials.isDisjoint(with: boundedObjects) {
        return "led"
      }
      if preposition == "from", !leadMetalFromSources.isDisjoint(with: boundedObjects) {
        return "led"
      }
    }
    if let previousWord, leadMetalImmediateLeftContexts.contains(previousWord) {
      return "led"
    }
    if adjacentWord == nil,
       let previousWord,
       leadMetalTerminalObjectLeftContexts.contains(previousWord) {
      return "led"
    }
    if let previousWord, let wordBeforePrevious {
      if leadMetalTwoWordLeftContexts.contains("\(wordBeforePrevious) \(previousWord)") {
        return "led"
      }
      if hasListEvidence {
        return "led"
      }
    }
    return nil
  }

  /// The two left-context rules never need more than two words. Stop at a
  /// clause boundary so `Mercury spilled. And lead the team.` cannot borrow
  /// the element from the prior sentence; commas remain transparent so the
  /// reported `mercury, and lead` enumeration still resolves.
  private static func precedingClauseWords(_ tokens: [MToken], before endIndex: Int) -> [String] {
    var words: [String] = []
    for index in tokens.indices[..<endIndex].reversed() {
      let token = tokens[index]
      if isContextBoundary(tokens, at: index) {
        break
      }
      if let word = normalizedWord(token) {
        words.append(word)
        if words.count == 2 { break }
      }
    }
    return words
  }

  /// Right-context material phrases need at most four words: `in the drinking
  /// water` is the longest supported shape. The same clause boundaries as the
  /// backward scan keep evidence from leaking across publisher punctuation.
  private static func followingClauseWords(_ tokens: [MToken], after startIndex: Int) -> [String] {
    var words: [String] = []
    guard startIndex < tokens.index(before: tokens.endIndex) else { return words }

    for index in tokens.index(after: startIndex)..<tokens.endIndex {
      let token = tokens[index]
      if isContextBoundary(tokens, at: index) {
        break
      }
      if let word = normalizedWord(token) {
        words.append(word)
        if words.count == 4 { break }
      }
    }
    return words
  }

  private static func isContextBoundary(_ tokens: [MToken], at index: Int) -> Bool {
    let token = tokens[index]
    if token.text.contains(where: contextBoundaryCharacters.contains) {
      return true
    }
    return isSpacedASCIIDash(tokens, at: index)
  }

  private static func isSpacedASCIIDash(_ tokens: [MToken], at index: Int) -> Bool {
    guard isASCIIDash(tokens[index]) else { return false }

    var firstDash = index
    while firstDash > tokens.startIndex {
      let candidate = tokens.index(before: firstDash)
      guard isASCIIDash(tokens[candidate]), tokens[candidate].whitespace.isEmpty else { break }
      firstDash = candidate
    }

    var lastDash = index
    while tokens[lastDash].whitespace.isEmpty,
          lastDash < tokens.index(before: tokens.endIndex) {
      let candidate = tokens.index(after: lastDash)
      guard isASCIIDash(tokens[candidate]) else { break }
      lastDash = candidate
    }

    guard firstDash > tokens.startIndex else { return false }
    let tokenBeforeDash = tokens[tokens.index(before: firstDash)]
    return !tokenBeforeDash.whitespace.isEmpty && !tokens[lastDash].whitespace.isEmpty
  }

  private static func isASCIIDash(_ token: MToken) -> Bool {
    !token.text.isEmpty && token.text.allSatisfy { $0 == "-" }
  }

  private static func isHyphenatedToFollowingWord(_ tokens: [MToken], at index: Int) -> Bool {
    guard tokens[index].whitespace.isEmpty,
          index < tokens.index(before: tokens.endIndex) else { return false }
    let hyphenIndex = tokens.index(after: index)
    guard tokens[hyphenIndex].text == "-", tokens[hyphenIndex].whitespace.isEmpty,
          hyphenIndex < tokens.index(before: tokens.endIndex) else { return false }
    return normalizedWord(tokens[tokens.index(after: hyphenIndex)]) != nil
  }

  private static func normalizedWord(_ token: MToken) -> String? {
    guard token.text.contains(where: \.isLetter) else { return nil }
    return token.text.lowercased()
  }
}
