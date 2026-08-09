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

  private static let liveMediaRightContexts: Set<String> = [
    "audio", "blog", "broadcast", "coverage", "event", "feed", "music", "performance",
    "radio", "show", "stream", "television", "tv", "video"
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
        wordBeforePrevious: wordBeforePrevious
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
    wordBeforePrevious: String? = nil
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
      guard currentTag == nil || currentTag == .otherWord else {
        return currentTag
      }
      if let nextWord, liveMediaRightContexts.contains(nextWord) {
        return currentTag
      }
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
