import Foundation
import MLXUtilsLibrary

// A forced span glued to other text inside one token.
//
// A `[word](/ipa/)` span is aligned to the tagger's tokens by range, and the
// token that holds the span took its reading whole. The tokenizer does not
// cut at a span, only where spaCy cuts, so whatever it left in the same token
// was replaced with the label:
//
//     A [word](/wˈɜɹd/)next.              ɐ wˈɜɹd.         "next" gone
//     The 1990s[word](/ænd/) more.        ði ænd mˈɔɹ.     "1990s" gone
//     A [one](/wˈʌn/)[two](/tˈu/) next.   ɐ tˈu nˈɛkst.    the first span gone
//     Open vocab.[json](/ʤˈAsᵊn/) now.    ˈOpᵊn ʤˈAsᵊn nˈW.
//     [Verizon](/vəɹˈIzᵊn/)'d pay.        vəɹˈIzᵊn pˈA.
//
// Two spans in one token each claimed it, and the last one won. A label that
// ended inside a token left that token its own reading, so the label's last
// word was said twice: "[T-Mobile](/tˈimˈObᵊl/)'d" was `tˈimˈObᵊlmˈObᵊld`.
// The text need not touch the span: a period between lower-case letters, an
// underscore, a hyphen or a slash before a figure and a clitic spaCy has no
// special case for all stay inside the token. Upstream aligns with spaCy's
// `Alignment`, which hands a token to every span that touches it, and reads
// the same way.
//
// The token is cut at the span's ends instead, before the readings are
// aligned, so the span is a token of its own and the rest keeps the reading
// it has on its own. The cut adds nothing between the pieces: only the last
// one carries the token's whitespace.
extension EnglishG2P {

  /// Cuts each token that a forced reading starts or ends inside, at those
  /// points.
  ///
  /// Only a span that forces phonemes cuts. A stress or a number flag changes
  /// how its token is read and replaces nothing, so it still goes to the
  /// whole token, which is read as one word as before.
  ///
  /// A piece keeps its token's tag. The tagger read the token whole and has
  /// no reading of the pieces, and re-tagging them would move the tags of
  /// the words around them as well. The first piece is the token itself, cut
  /// short, so the tag map holds no entry for a token that is gone. The
  /// others are copied from the token as it was, since the first may have
  /// been emptied by then.
  ///
  /// The period that closes an abbreviation stays with the label before it.
  /// spaCy keeps that period in the token ("Dr.", "U.S.", "p.m."), and a span
  /// on the abbreviation has always taken it: cut off, it is a full stop in
  /// front of the name ("[Dr](/dˈɑktəɹ/). Smith" read `dˈɑktəɹ. smˈɪθ`). A
  /// caller that wants the period read where it also ends a sentence writes
  /// it into the label and the phonemes. spaCy also keeps the period after a
  /// lone capital, which may be an initial, and there it is as often the
  /// sentence's own: that one is cut off and read (`isAbbreviation`).
  ///
  /// The tokens are in text order and so are the spans, so one pass over each
  /// finds every cut.
  func cutTokens(
    _ tokens: [MToken],
    at features: [PreprocessFeature],
    in text: String,
    pennTags: inout PennTagMap
  ) -> [MToken] {
    var labelStarts: Set<String.Index> = []
    var bounds: [String.Index] = []
    for feature in features where feature.forcesPhonemes {
      labelStarts.insert(feature.tokenRange.lowerBound)
      bounds.append(feature.tokenRange.lowerBound)
      bounds.append(feature.tokenRange.upperBound)
    }
    guard !bounds.isEmpty else { return tokens }

    var result: [MToken] = []
    result.reserveCapacity(tokens.count)
    var next = 0
    for token in tokens {
      let end = token.tokenRange.upperBound
      var start = token.tokenRange.lowerBound
      while next < bounds.count, bounds[next] <= start { next += 1 }
      guard next < bounds.count, bounds[next] < end else {
        result.append(token)
        continue
      }

      let whole = MToken(copying: token)
      let pennTag = pennTags[ObjectIdentifier(token)]
      var piece = token
      while start < end {
        while next < bounds.count, bounds[next] <= start { next += 1 }
        var cut = next < bounds.count && bounds[next] < end ? bounds[next] : end
        if start > whole.tokenRange.lowerBound, let rest = EnglishG2P.endOfUnreadOpening(in: text[start..<cut]) {
          cut = rest
        } else if !labelStarts.contains(cut), text[cut..<end] == ".",
                  EnglishG2P.isAbbreviation(text[whole.tokenRange.lowerBound..<cut]) {
          cut = end
        }
        piece.text = String(text[start..<cut])
        piece.tokenRange = start..<cut
        piece.whitespace = cut == end ? whole.whitespace : ""
        if !piece.text.contains(where: EnglishG2P.isRead) {
          piece.phonemes = ""
          piece.`_`.rating = 3
        }
        result.append(piece)
        start = cut
        if start < end {
          piece = MToken(copying: whole)
          pennTags[ObjectIdentifier(piece)] = pennTag
        }
      }
    }
    return result
  }

  /// Whether what stands before a token's closing period is an abbreviation:
  /// it holds a period of its own ("U.S", "p.m") or does not end on a capital
  /// ("Dr", "Inc", "vs"). What is left is a lone capital after anything but a
  /// capital ("SpaceX.", "pH.", "plan B."), where spaCy keeps the period in
  /// case the capital is an initial. A span there took the sentence's full
  /// stop: "It is from [SpaceX](/spˈAsˈɛks/). The next one flew." ran on.
  private static func isAbbreviation(_ stem: Substring) -> Bool {
    stem.contains(".") || stem.last?.isUppercase != true
  }

  /// Whether a character is one a piece can be read for: a letter, a digit,
  /// a mark, or a symbol the lexicon has a word for ("+", "&", "@", "%"). A
  /// piece that holds none reads as nothing. A superscript is no digit: a
  /// footnote's "¹" after a span read "one". Nor is a combining mark typed
  /// after the label a letter (a decomposed "Duó" under a span on "Duo"):
  /// it is a piece of its own, and emptied.
  ///
  /// Inside a token that is already its reading: junk the lexicon cannot
  /// place is emptied by the group it shares, and so are the hyphens of a
  /// flag. Cut off, with a span on one side, such a piece is a group of one,
  /// and a group of one is a word: the fallback names a letter for it, so
  /// "--[json](/ʤˈAsᵊn/)" read `dˈiʤˈAsᵊn` and a dagger after a span `ˈɛks`.
  /// Before the cut the span took all of these with it, and none was heard.
  private static func isRead(_ character: Character) -> Bool {
    character.isLetter || readMarks.contains(character)
      || character.unicodeScalars.first?.properties.generalCategory == .decimalNumber
  }

  /// The marks `retokenize` voices whatever the tag, and the lexicon's symbols.
  private static let readMarks = punctuactions.union("()–").union(Lexicon.symbolSet.keys.compactMap(\.first))

  /// Where the characters that open a piece with nothing to read in them
  /// end, or nil for a piece that opens on something read, or holds nothing
  /// that is.
  ///
  /// Asked of every piece but a token's first, and the opening becomes a
  /// piece of its own, which reads as nothing. The hyphen is the reason:
  /// `subtokenize` takes one that opens a token for the sign of the figure
  /// after it, and the cut is what put this one there. "[COVID](/kˈOvɪd/)-19"
  /// read `kˈOvɪdmˈInəs nˌIntˈin`, where "COVID-19" whole has no "minus". Any
  /// other opening the frontend cannot read sent the whole piece to the
  /// fallback, figure and all: a non-breaking hyphen there read `kˈOvɪdˈɛks`.
  /// A hyphen that opens the token is still the sign it was, and an
  /// apostrophe is left where it is, since it opens a clitic.
  private static func endOfUnreadOpening(in piece: Substring) -> String.Index? {
    guard let rest = piece.firstIndex(where: { isRead($0) || apostrophes.contains($0) }),
          rest > piece.startIndex else { return nil }
    return rest
  }

  private static let apostrophes: Set<Character> = ["'", "\u{2019}", "\u{2018}"]
}
