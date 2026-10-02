import Foundation
import MLXUtilsLibrary

// A hyphenated compound the lexicon lists whole, read from its own entry.
//
// spaCy splits "sci-fi" into "sci", "-", "fi", and `retokenize` gives a
// word-joining hyphen an empty reading of its own. A token that already has a
// reading stands alone, so the three never share a subtoken group, the merged
// lookup that would find gold's `sci-fi` is never made, and each half is
// resolved by itself. Neither half is a word: both go to the fallback
// network, which reads a spelling. American "sci-fi" came back `sˈIfˈi`
// ("sigh-fee"), British "Sci-Fi" `sˈiːfˈiː` ("see-fee"), British "Wi-Fi"
// `wˈiːfˈiː`, American "wi-fi" `wˈifˈi`, each beside a gold entry that reads
// it correctly. Upstream reaches those entries: spaCy tags the hyphen `HYPH`,
// which is not one of its punctuation tags, so the hyphen stays in the group.
//
// The hyphen is therefore left in its group exactly where that is what the
// reading needs: the lexicon lists the compound, and some part of it has no
// reading of its own. A compound whose parts all read keeps the part-by-part
// reading it has always had here, listed or not. Gold lists about 3,400
// hyphenated keys a dialect, and reading all of them whole would move the
// stress of "long-term" and of the handful of spelled-out numbers gold
// happens to list ("forty-five" beside an unlisted "forty-six").
extension EnglishG2P {

  /// The longest run of hyphen-joined words judged at once: gold's longest
  /// hyphenated key has seven parts ("what-you-see-is-what-you-get").
  private static let longestCompound = 7

  /// Whether the hyphen at `index` joins words inside a compound that the
  /// lexicon lists whole and cannot read part by part.
  ///
  /// The run of words around the hyphen is cut into listed compounds from the
  /// left, longest first, so the answer for one hyphen agrees with the answer
  /// for its neighbours: every hyphen kept lies inside one compound, and the
  /// hyphen between two compounds is not kept. Each subtoken group is then a
  /// single listed compound, which the merged lookup reads.
  func joinsListedCompound(_ tokens: [MToken], at index: Int) -> Bool {
    guard isCompoundHyphen(tokens, at: index) else { return false }

    // The words of the run: every second token, out from the hyphen.
    var first = index - 1
    while first >= 2, isCompoundHyphen(tokens, at: first - 1) { first -= 2 }
    var last = index + 1
    while last + 2 < tokens.count, isCompoundHyphen(tokens, at: last + 1) { last += 2 }
    let words = Array(stride(from: first, through: last, by: 2))
    guard words.count <= EnglishG2P.longestCompound else { return false }

    var start = 0
    while start < words.count - 1 {
      var end = words.count - 1
      while end > start, !isListedCompound(words[start...end].map { tokens[$0].text }) { end -= 1 }
      if end > start {
        if words[start] < index, index < words[end] { return true }
        start = end + 1
      } else {
        start += 1
      }
    }
    return false
  }

  /// A lone hyphen glued to a plain, unresolved word on each side.
  private func isCompoundHyphen(_ tokens: [MToken], at index: Int) -> Bool {
    guard index >= 1, index + 1 < tokens.count, tokens[index].text == "-",
          tokens[index].whitespace.isEmpty, tokens[index - 1].whitespace.isEmpty else { return false }
    return isCompoundPart(tokens[index - 1]) && isCompoundPart(tokens[index + 1])
  }

  /// A word `retokenize` passes through as one unresolved subtoken: ASCII
  /// letters, no alias or forced reading, and no case boundary inside it.
  private func isCompoundPart(_ token: MToken) -> Bool {
    guard !token.text.isEmpty, token.phonemes == nil, token.`_`.alias == nil,
          token.text.unicodeScalars.allSatisfy({ $0.isASCII && $0.properties.isAlphabetic }) else { return false }
    return subtokenize(word: token.text).count == 1
  }

  private func isListedCompound(_ parts: [String]) -> Bool {
    lexicon.listsCompound(parts.joined(separator: "-")) && !parts.allSatisfy(lexicon.reads)
  }
}
