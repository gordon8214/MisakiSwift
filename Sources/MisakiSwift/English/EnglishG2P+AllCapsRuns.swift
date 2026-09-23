import Foundation

/// Re-tags text set in capitals from the same text in lower case.
///
/// spaCy's tagger reads casing, and a run of capitals looks to it like a row
/// of names: "HE TOLD US ABOUT IT" comes back PRP VBD NNP IN PRP, and "MY",
/// "AT", "ON", "SO" and "BY" are NNP or NN nearly everywhere. The lexicon
/// spells a short all-caps token so tagged -- an NNP gold word with no
/// primary stress, or a noun-tagged initialism entry such as "IT" -- so a
/// headline in capitals was read out letter by letter. An all-caps
/// contraction is worse off: spaCy splits "won't" but not "WON'T", the
/// single token it gets instead is one it never saw, and when that is tagged
/// as punctuation the word is dropped from the audio.
///
/// Inside such a run the capitals carry no information, so the run is tagged
/// again with its letters folded to lower case, which is how the tagger saw
/// prose in training. That tag replaces only the tags capitals produce, and
/// only where the lexicon has no reason to keep the initialism.
///
/// A deliberate divergence from upstream misaki, which tags the text as given
/// and applies the same `is_NNP` rules to whatever comes back.
extension EnglishG2P {
  /// The tags of `trace`, with the tokens of every all-caps run re-tagged as
  /// described above. `text` is the string `trace` was made from.
  func allCapsRunTags(for trace: SpacyTaggerTrace, in text: String, tagger: SpacyEnglishTagger) -> [String] {
    let members = AllCapsRun.members(of: trace.tokens.map(\.text), isWord: lexicon.listsAsLowercaseWord)
    guard !members.isEmpty else { return trace.pennTags }

    let folded = AllCapsRun.folding(trace.tokens, of: text, members: members)
    let refolded = tagger.trace(folded.text)
    let refoldedSpans = AllCapsRun.utf16Spans(of: refolded.tokens, in: folded.text)

    var tags = trace.pennTags
    var cursor = 0
    for index in trace.tokens.indices where members.contains(index) {
      let span = folded.spans[index]
      while cursor < refoldedSpans.count, refoldedSpans[cursor].upperBound <= span.lowerBound { cursor += 1 }
      // Folding can split a token the capitals kept whole ("WON'T" is one
      // token, "won't" is "wo" + "n't"; spaCy's apostrophe-free special cases
      // split "id" into "i" + "d" and "cannot" into "can" + "not") or merge
      // two ("50" + "K" is "50k"). A token takes the tag of its first piece
      // with a letter in it, never a leading hyphen or quote; the rules below
      // are what keep a borrowed tag from reaching the lexicon.
      var match = cursor
      while match < refoldedSpans.count, refoldedSpans[match].overlaps(span),
            !refolded.tokens[match].text.contains(where: \.isLetter) {
        match += 1
      }
      guard match < refoldedSpans.count, refoldedSpans[match].overlaps(span) else { continue }
      // A lone capital joined to a word by a hyphen is a letter ("TRIPLE-A",
      // "RETIN-A"), whatever lower case makes of "a".
      if trace.tokens[index].text.count == 1, AllCapsRun.isHyphenJoined(index, in: trace.tokens) { continue }
      if acceptsFoldedTag(
        refolded.pennTags[match],
        confidence: refolded.confidences[match],
        for: trace.tokens[index].text,
        taggedInCapitals: trace.pennTags[index]
      ) {
        tags[index] = refolded.pennTags[match]
      }
    }
    return tags
  }

  /// Whether a run token's lower-case tag replaces the one it got in
  /// capitals.
  ///
  /// Measured over 9,208 article sentences uppercased whole, each token
  /// against its reading in the original casing, and checked on 4,310
  /// further article sentences and 5,704 Wall Street Journal and inaugural
  /// sentences. Each rule was added because a run without it moved a token
  /// that read correctly, and `AllCapsRunTests` has a sentence that moves
  /// without it -- except the noun-tag rule, which the heteronym rule now
  /// covers on those corpora, and the refused punctuation tag, never seen
  /// there. Both are kept because each bounds what a re-tag may do.
  func acceptsFoldedTag(
    _ folded: String,
    confidence: Float,
    for token: String,
    taggedInCapitals capitals: String
  ) -> Bool {
    guard folded != capitals, AllCapsRun.isWordShaped(token) else { return false }

    // A letter token tagged as punctuation is one the tagger could not read
    // at all, and punctuation is dropped from the audio. Any tag beats that.
    if AllCapsRun.punctuationTags.contains(capitals) { return true }

    // Otherwise only a noun tag is the capitals' doing. A verb or an
    // adjective the tagger chose in spite of them is its reading of the
    // sentence.
    guard AllCapsRun.nounTags.contains(capitals) else { return false }
    // The fold may demote a noun but never promote one to a name or a number:
    // spaCy calls a lower-case "xi" NNP, and NNP is what spells a short word,
    // while CD moves a currency word ("$50K BONUSES").
    guard !AllCapsRun.promotedTags.contains(folded) else { return false }
    // Nor to punctuation, which would drop the word exactly as above.
    guard !AllCapsRun.punctuationTags.contains(folded) else { return false }

    // A heteronym is read either way, never spelled, so the tag would only
    // choose a sense, and there capitals were information: Title-case "Live
    // Weather" and a "Close" button kept the name's reading, which the
    // lower-case tagger turned into a verb.
    if lexicon.readsByPartOfSpeech(token), !lexicon.isInitialismEntry(token) { return false }

    // Where gold reads the capitals apart from the lower-case word, the
    // capitals are the information. "AI" reads as gold's "AI" under any tag,
    // but its possessive does not: "AI'S" tagged NN goes to lower case, and
    // British gold has "ai", the sloth. (One letter is exempt: "A" is the
    // article or the letter by its tag, which is why it is re-tagged.)
    if token.count > 1, lexicon.listsCapitalsApart(token) { return false }

    // "UPS", "IOS", "SOS" and "IDS" reach a word only through `stem_s`, from
    // "up", "io", "so" and "id". A short token the lexicon knows only by
    // derivation is an initialism.
    let letters = token.prefix { $0 != "'" && $0 != "\u{2019}" }.filter(\.isLetter).count
    if letters <= 3, !lexicon.listsWord(token.lowercased()) { return false }

    // Gold marks some spellings as initialisms as well as words: "US",
    // "IT", "OS", "ID", "SAT". Without casing, the lower-case tagger chooses
    // between them, and it guesses exactly where the word is rare ("the os
    // update") or the pronoun ungrammatical ("in the western us"). Every flip
    // it got wrong scored under 0.99; the pronouns it got right mostly
    // scored 1.0.
    // (Written so that a NaN confidence fails the gate.)
    if lexicon.isInitialismEntry(token), !(confidence >= AllCapsRun.initialismConfidence) { return false }

    return true
  }
}

/// The parts of `EnglishG2P.allCapsRunTags` that need neither lexicon nor
/// tagger.
enum AllCapsRun {
  static let nounTags: Set<String> = ["NN", "NNS", "NNP", "NNPS"]
  static let promotedTags: Set<String> = ["NNP", "NNPS", "CD"]
  static let punctuationTags: Set<String> = [".", ",", ":", "''", "``", "-LRB-", "-RRB-", "HYPH", "NFP"]
  static let initialismConfidence: Float = 0.99
  static let hyphens: Set<String> = ["-", "\u{2010}", "\u{2011}"]

  /// The indices of the tokens that sit in a run of capitals.
  ///
  /// A run is a maximal stretch of tokens with no lower-case letter; tokens
  /// without a letter (digits, punctuation) neither join nor break one. It
  /// counts only with at least two tokens of two letters or more, one of
  /// which `isWord` -- a word the lexicon lists in lower case. Prose puts
  /// acronyms side by side ("RAM / SSD", "US EU EU") but never makes such a
  /// run, and neither does a single emphasized word.
  static func members(of texts: [String], isWord: (String) -> Bool) -> Set<Int> {
    var members: Set<Int> = []
    var run: [Int] = []
    func close() {
      if run.filter({ texts[$0].filter(\.isLetter).count >= 2 }).count >= 2,
         run.contains(where: { isWord(texts[$0]) }) {
        members.formUnion(run)
      }
      run = []
    }
    for (index, text) in texts.enumerated() where text.contains(where: \.isLetter) {
      if text.contains(where: \.isLowercase) || !text.contains(where: \.isUppercase) {
        close()
      } else {
        run.append(index)
      }
    }
    close()
    return members
  }

  /// Whether a hyphen joins token `index` to a neighbouring word, with no
  /// space on either side of the hyphen.
  static func isHyphenJoined(_ index: Int, in tokens: [SpacyTokenizedWord]) -> Bool {
    if index >= 2, hyphens.contains(tokens[index - 1].text), !tokens[index - 2].isSpace,
       tokens[index - 2].whitespace.isEmpty, tokens[index - 1].whitespace.isEmpty {
      return true
    }
    if index + 2 < tokens.count, hyphens.contains(tokens[index + 1].text), !tokens[index + 2].isSpace,
       tokens[index].whitespace.isEmpty, tokens[index + 1].whitespace.isEmpty {
      return true
    }
    return false
  }

  /// Whether `token` has a word's shape: letters, with apostrophes only
  /// after the first. "IPHONE" and "WON'T" do; "'S" (tagged apart already),
  /// a quoted "'S'" and "-SIZED" do not.
  static func isWordShaped(_ token: String) -> Bool {
    guard let first = token.first, first.isLetter else { return false }
    return token.allSatisfy { $0.isLetter || $0 == "'" || $0 == "\u{2019}" }
  }

  /// A token as prose writes it: in lower case, except the pronoun "I",
  /// which prose capitalizes on its own and in "I'm".
  static func caseFolded(_ token: String) -> String {
    guard token.hasPrefix("I") else { return token.lowercased() }
    let rest = token.dropFirst()
    guard rest.isEmpty || rest.first == "'" || rest.first == "\u{2019}" else { return token.lowercased() }
    return "I" + rest.lowercased()
  }

  /// `text` with each member token case-folded, and where every token now
  /// sits in it, in UTF-16 offsets.
  static func folding(
    _ tokens: [SpacyTokenizedWord],
    of text: String,
    members: Set<Int>
  ) -> (text: String, spans: [Range<Int>]) {
    var folded = ""
    var spans: [Range<Int>] = []
    var cursor = text.startIndex
    var offset = 0
    for (index, token) in tokens.enumerated() {
      let gap = text[cursor..<token.range.lowerBound]
      folded += gap
      offset += gap.utf16.count
      let written = members.contains(index) ? caseFolded(token.text) : token.text
      folded += written
      spans.append(offset..<(offset + written.utf16.count))
      offset += written.utf16.count
      cursor = token.range.upperBound
    }
    folded += text[cursor...]
    return (folded, spans)
  }

  /// Where each of `tokens` sits in `text`, in UTF-16 offsets.
  static func utf16Spans(of tokens: [SpacyTokenizedWord], in text: String) -> [Range<Int>] {
    var spans: [Range<Int>] = []
    var cursor = text.startIndex
    var offset = 0
    for token in tokens {
      offset += text.utf16.distance(from: cursor, to: token.range.lowerBound)
      let length = text.utf16.distance(from: token.range.lowerBound, to: token.range.upperBound)
      spans.append(offset..<(offset + length))
      offset += length
      cursor = token.range.upperBound
    }
    return spans
  }
}
