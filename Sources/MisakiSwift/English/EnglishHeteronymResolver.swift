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

  static func resolve(tokens: [MToken]) {
    for (index, token) in tokens.enumerated() where token.phonemes == nil {
      let previousWord = tokens[..<index].reversed().compactMap(normalizedWord).first
      let nextWord = tokens.dropFirst(index + 1).compactMap(normalizedWord).first
      token.tag = resolvedTag(
        for: token.text,
        currentTag: token.tag,
        previousWord: previousWord,
        nextWord: nextWord
      )
    }
  }

  static func resolvedTag(
    for word: String,
    currentTag: NLTag?,
    previousWord: String?,
    nextWord: String?
  ) -> NLTag? {
    guard word.lowercased() == "live",
          currentTag == nil || currentTag == .otherWord else {
      return currentTag
    }

    if let nextWord, liveMediaRightContexts.contains(nextWord) {
      return currentTag
    }
    if let previousWord, liveVerbLeftContexts.contains(previousWord) {
      return .verb
    }
    return currentTag
  }

  private static func normalizedWord(_ token: MToken) -> String? {
    guard token.text.contains(where: \.isLetter) else { return nil }
    return token.text.lowercased()
  }
}
