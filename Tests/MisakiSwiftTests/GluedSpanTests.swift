import Testing
@testable import MisakiSwift

/// A `[word](/ipa/)` span joins the text glued to it, and replaces only its
/// own label.
///
/// A span is aligned to the tagger's tokens by range, and the token that held
/// it took the forced reading whole. spaCy cuts a token at whitespace and at a
/// short list of marks, never at a span, so whatever else it left in that
/// token lost its reading: a letter or a figure against the span, a second
/// span, a file name's stem before a period, a clitic spaCy has no special
/// case for. `cutTokens` cuts the token at the span's ends before the
/// readings are aligned. Every "was" below was measured at `a1101e0`.
struct GluedSpanTests {

  private static func expectReadings(_ fixtures: [(text: String, american: String, british: String)]) {
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)
    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "wrong American reading for \(fixture.text.debugDescription)")
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "wrong British reading for \(fixture.text.debugDescription)")
    }
  }

  /// A letter or a figure against the span, on either side. Each was the
  /// span alone: `ɐ wˈɜɹd.` twice, `ði ænd mˈɔɹ.`, `sˈi wˈɜɹd hˈɪɹ.`,
  /// `sˈi fˈOn hˈɪɹ.` and `mək sˈɛd sˌO.`.
  @Test func aSpanJoinsTheLetterOrFigureGluedToIt() {
    Self.expectReadings([
      ("A [word](/wˈɜɹd/)next.", "ɐ wˈɜɹdnˈɛkst.", "ɐ wˈɜɹdnˈɛkst."),
      ("A next[word](/wˈɜɹd/).", "ɐ nˈɛkstwˈɜɹd.", "ɐ nˈɛkstwˈɜɹd."),
      ("The 1990s[word](/ænd/) more.",
       "ðə nˌIntˈin nˈIndiz ænd mˈɔɹ.", "ðə nˌIntˈiːn nˈIntiz ænd mˈɔː."),
      ("See [word](/wˈɜɹd/)2 here.", "sˈi wˈɜɹdtˈu hˈɪɹ.", "sˈiː wˈɜɹdtˈuː hˈɪə."),
      ("See i[Phone](/fˈOn/) here.", "sˈi ˈIfˈOn hˈɪɹ.", "sˈiː ˈIfˈOn hˈɪə."),
      ("[Mc](/mək/)Donald said so.", "məkdˈɑnəld sˈɛd sˌO.", "məkdˈɒnᵊld sˈɛd sˌQ.")
    ])
  }

  /// Two spans in one token each claimed the whole of it and the second won:
  /// `ɐ tˈu nˈɛkst.` and `ðə tˈi dˈil.`, the ampersand gone with the first.
  @Test func twoSpansInOneTokenAreBothRead() {
    Self.expectReadings([
      ("A [one](/wˈʌn/)[two](/tˈu/) next.", "ɐ wˈʌntˈu nˈɛkst.", "ɐ wˈʌntˈu nˈɛkst."),
      ("The [AT](/ˌAtˈi/)&[T](/tˈi/) deal.", "ði ˌAtˈiændtˈi dˈil.", "ði ˌAtˈiandtˈi dˈiːl.")
    ])
  }

  /// A label over several tokens that ends, or starts, inside one. That
  /// token reaches past the span, so it was never the span's and kept its
  /// own reading, and a word of the label was said twice: the last in
  /// `tˈimˈObᵊlmˈObᵊld` ("T-Mobile mobile'd"), the first in `æt tˈitˈimˈObᵊl`.
  @Test func aLabelThatEndsInsideATokenIsNotReadTwice() {
    Self.expectReadings([
      ("The [T-Mobile](/tˈimˈObᵊl/)'d go.", "ðə tˈimˈObᵊld ɡˌO.", "ðə tˈimˈObᵊld ɡˌQ."),
      ("An @[T-Mobile](/tˈimˈObᵊl/) post.", "ɐn ættˈimˈObᵊl pˈOst.", "ɐn attˈimˈObᵊl pˈQst.")
    ])
  }

  /// The same where the label's last piece was left longer than the label,
  /// by an abbreviation's period, and where a combining mark follows it.
  /// The longer piece neither holds the span nor lies inside it, so a span
  /// claims what it overlaps. These read `ˈækmi ˈɪŋk ˈɪŋk.` and `dˈuˌO dˈubz`
  /// at `a1101e0`, and the first still did by containment.
  @Test func aLabelsLastPieceIsItsOwnWhereItIsLongerThanTheLabel() {
    Self.expectReadings([
      ("Meet [Acme Inc](/ˈækmi ˈɪŋk/). Next week.", "mˈit ˈækmi ˈɪŋk nˈɛkst wˈik.", "mˈiːt ˈækmi ˈɪŋk nˈɛkst wˈiːk."),
      ("The [iPhone Duo](/ˈIfˌOn dˈuˌO/)\u{301}'s screen folds.",
       "ði ˈIfˌOn dˈuˌOz skɹˈin fˈOldz.", "ði ˈIfˌOn dˈuˌOz skɹˈiːn fˈQldz.")
    ])
  }

  /// The glue need not be a letter. spaCy leaves a period between lower-case
  /// letters, an underscore, a plus sign and a clitic it has no special case
  /// for inside the token, and each row lost what stood across that mark:
  /// `ˈOpᵊn ʤˈAsᵊn ænd`, `ðə sˌiˌɛnˈɛn lˈAəɹ`, `ðə wˈɜɹd hˈɪɹ`, `ɐ wˈɜɹd θˈɪŋ`
  /// and `vəɹˈIzᵊn ɡˌO`. A file name is the shape prose has most of: a row for
  /// "JSON" is a span on every "vocab.json".
  @Test func aSpanLeavesTheRestOfItsTokenItsOwnReading() {
    Self.expectReadings([
      ("Open vocab.[json](/ʤˈAsᵊn/) and read it.",
       "ˈOpᵊn vˈOkˌæb.ʤˈAsᵊn ænd ɹˈɛd ɪt.", "ˈQpᵊn vˈQkab.ʤˈAsᵊn and ɹˈɛd ɪt."),
      ("See the self.[cnn](/sˌiˌɛnˈɛn/) layer.",
       "sˈi ðə sˈɛlf.sˌiˌɛnˈɛn lˈAəɹ.", "sˈiː ðə sˈɛlf.sˌiˌɛnˈɛn lˈAə."),
      ("The [word](/wˈɜɹd/)_flag here.", "ðə wˈɜɹdflˈæɡ hˈɪɹ.", "ðə wˈɜɹdflˈaɡ hˈɪə."),
      ("A [word](/wˈɜɹd/)+ thing.", "ɐ wˈɜɹdplˈʌs θˈɪŋ.", "ɐ wˈɜɹdplˈʌs θˈɪŋ."),
      ("[Verizon](/vəɹˈIzᵊn/)'d go.", "vəɹˈIzᵊnd ɡˌO.", "vəɹˈIzᵊnd ɡˌQ."),
      ("[Verizon](/vəɹˈIzᵊn/)\u{2019}d go.", "vəɹˈIzᵊnd ɡˌO.", "vəɹˈIzᵊnd ɡˌQ.")
    ])
  }

  /// Nothing is put between the pieces, and the token's whitespace stays
  /// with the last of them, whichever side of the span it is on.
  @Test func onlyTheLastPieceCarriesTheTokensWhitespace() {
    Self.expectReadings([
      ("A [word](/wˈɜɹd/)next thing.", "ɐ wˈɜɹdnˈɛkst θˈɪŋ.", "ɐ wˈɜɹdnˈɛkst θˈɪŋ."),
      ("A next[word](/wˈɜɹd/) thing.", "ɐ nˈɛkstwˈɜɹd θˈɪŋ.", "ɐ nˈɛkstwˈɜɹd θˈɪŋ.")
    ])
  }

  /// A hyphen the cut leaves at the head of a piece was inside its token, and
  /// `subtokenize` would take it for a sign there: with the cut alone the
  /// first row read `kˈOvɪdmˈInəs nˌIntˈin`, where "COVID-19" whole has no
  /// "minus", and the third `wˈɜɹdmˈInəs pYnt fˈIv`. Whatever else opens a
  /// piece with nothing to read in it is set aside the same way, or the
  /// figure went to the fallback with it: the non-breaking hyphen read
  /// `kˈOvɪdˈɛks`. All four were the span alone before.
  ///
  /// A hyphen that opens the token is still the sign it was (the fifth row
  /// was `tə pˈYnts`, the figure gone). An en dash and a bracket are marks
  /// and are read (`vəɹˈIzᵊn lˈIn` and `wˈɜɹd) hˈɪɹ` before; the "s" in the
  /// bracket is the letter, as a bare one is).
  @Test func whatOpensAPieceUnreadIsSetAside() {
    Self.expectReadings([
      ("A [COVID](/kˈOvɪd/)-19 case.", "ɐ kˈOvɪdnˌIntˈin kˈAs.", "ɐ kˈOvɪdnˌIntˈiːn kˈAs."),
      ("A [COVID-](/kˈOvɪd/)19 case.", "ɐ kˈOvɪdnˌIntˈin kˈAs.", "ɐ kˈOvɪdnˌIntˈiːn kˈAs."),
      ("A [word](/wˈɜɹd/)-.5 thing.", "ɐ wˈɜɹdpYnt fˈIv θˈɪŋ.", "ɐ wˈɜɹdpYnt fˈIv θˈɪŋ."),
      ("Says [COVID](/kˈOvɪd/)\u{2011}19 today.", "sˈɛz kˈOvɪdnˌIntˈin tədˈA.", "sˈɛz kˈOvɪdnˌIntˈiːn tədˈA."),
      ("It fell to -19[points](/pˈYnts/) today.",
       "ˌɪt fˈɛl tə mˈInəs nˌIntˈinpˈYnts tədˈA.", "ˌɪt fˈɛl tə mˈInəs nˌIntˈiːnpˈYnts tədˈA."),
      ("The [Verizon](/vəɹˈIzᵊn/)\u{2013}5 line.", "ðə vəɹˈIzᵊn—fˈIv lˈIn.", "ðə vəɹˈIzᵊn—fˈIv lˈIn."),
      ("The [word](/wˈɜɹd/)(s) here.", "ðə wˈɜɹd(ˈɛs) hˈɪɹ.", "ðə wˈɜɹd(ˈɛs) hˈɪə.")
    ])
  }

  /// A combining mark typed after the label is a piece with nothing to read:
  /// the acute of a decomposed "Duó" under a span on "Duo". Both rows are
  /// unmoved. Read, the mark was a letter the fallback named (`dˈuˌOˈɛks ɪz`),
  /// and in the way of the possessive it left the clitic `s` (`dˈuˌOs`).
  @Test func aCombiningMarkAfterTheLabelReadsAsNothing() {
    Self.expectReadings([
      ("The [Duo](/dˈuˌO/)\u{301}'s screen folds.", "ðə dˈuˌOz skɹˈin fˈOldz.", "ðə dˈuˌOz skɹˈiːn fˈQldz."),
      ("The iPhone [Duo](/dˈuˌO/)\u{301} is here.", "ði ˈIfˌOn dˈuˌO ɪz hˈɪɹ.", "ði ˈIfˌQn dˈuˌO ɪz hˈɪə.")
    ])
  }

  /// A piece keeps the tag the tagger gave its token, which read "hasread"
  /// as a past form and "wordIT" as a name. With no tag the first is
  /// `hæzɹˈid` and the second `wˈɜɹdˈɪt`; both were the span alone.
  @Test func aPieceKeepsItsTokensTag() {
    Self.expectReadings([
      ("He [has](/hæz/)read it.", "hˌi hæzɹˈɛd ɪt.", "hˌiː hæzɹˈɛd ɪt."),
      ("A [word](/wˈɜɹd/)IT thing.", "ɐ wˈɜɹdˌItˈi θˈɪŋ.", "ɐ wˈɜɹdˌItˈiː θˈɪŋ.")
    ])
  }

  /// A piece with nothing in it to read reads as nothing, as it does inside
  /// a token. Cut off beside a span it is a word of its own, and the fallback
  /// names a letter for one: with the cut alone the flag read
  /// `wɪð dˈiʤˈAsᵊn` (British `ˈiːʤˈAsᵊn`) and the dagger `vəɹˈIzᵊnˈɛks`. Those
  /// two rows are unmoved from before the cut, when the span took the piece
  /// with it; the others were `ðə wˈɜɹd flˈæɡ`, `ˈOpᵊn sˈɛvən nˈW` and
  /// `ðə ɹˈOl bˈænd`. A period is a mark and is read: the last two rows
  /// were `ðə ʤˈAsᵊn fˈIl` and `vəɹˈIzᵊn tədˈA ɪt`, and the dagger before
  /// that period is still set aside and not read with it (`vəɹˈIzᵊnˈɛks.`).
  /// A superscript is no figure: a footnote's "¹" read `vəɹˈIzᵊnwˈʌn` with
  /// the cut alone.
  @Test func aPieceWithNothingToReadReadsAsNothingAndAMarkIsRead() {
    Self.expectReadings([
      ("Run it with --[json](/ʤˈAsᵊn/) for agents.",
       "ɹˈʌn ɪt wɪð ʤˈAsᵊn fɔɹ ˈAʤᵊnts.", "ɹˈʌn ɪt wɪð ʤˈAsᵊn fɔː ˈAʤᵊnts."),
      ("Says [Verizon](/vəɹˈIzᵊn/)\u{2020} today.", "sˈɛz vəɹˈIzᵊn tədˈA.", "sˈɛz vəɹˈIzᵊn tədˈA."),
      ("Says [Verizon](/vəɹˈIzᵊn/)\u{B9} today.", "sˈɛz vəɹˈIzᵊn tədˈA.", "sˈɛz vəɹˈIzᵊn tədˈA."),
      ("The [my](/mI/)_[word](/wˈɜɹd/) flag.", "ðə mIwˈɜɹd flˈæɡ.", "ðə mIwˈɜɹd flˈaɡ."),
      ("Open [24](/twˈɛnti fˈɔɹ/)/[7](/sˈɛvən/) now.",
       "ˈOpᵊn twˈɛnti fˈɔɹsˈɛvən nˈW.", "ˈQpᵊn twˈɛnti fˈɔɹsˈɛvən nˈW."),
      ("The [rock](/ɹˈɑk/)'[n](/ən/)'[roll](/ɹˈOl/) band.", "ðə ɹˈɑkənɹˈOl bˈænd.", "ðə ɹˈɑkənɹˈOl bˈand."),
      ("The [vocab](/vˈOkˌæb/).[json](/ʤˈAsᵊn/) file.",
       "ðə vˈOkˌæb.ʤˈAsᵊn fˈIl.", "ðə vˈOkˌæb.ʤˈAsᵊn fˈIl."),
      ("Says [Verizon](/vəɹˈIzᵊn/)\u{2020}. Today it rained.",
       "sˈɛz vəɹˈIzᵊn. tədˈA ɪt ɹˈAnd.", "sˈɛz vəɹˈIzᵊn. tədˈA ɪt ɹˈAnd.")
    ])
  }

  /// The possessive is re-voiced against the span, and looks past a piece
  /// the cut emptied to find it. With the dagger between them the clitic
  /// was the bare `s`, `bˈOzs`; the row is unmoved from before the cut.
  @Test func aPossessiveLooksPastAnEmptiedPiece() {
    Self.expectReadings([
      ("[Bose](/bˈOz/)\u{2020}'s speakers.", "bˈOzᵻz spˈikəɹz.", "bˈOzɪz spˈiːkəz.")
    ])
  }

  /// A piece is read whatever the piece before it was. The first piece is
  /// the token itself, and a later one copied from it once it had been
  /// emptied was empty too: the text after the span was still lost
  /// (`ɹˈʌn ʤˈAsᵊn nˈW`, `sˈi jˈuzəɹ hˈɪɹ`, as before the cut).
  @Test func aPieceAfterAnEmptiedOneIsStillRead() {
    Self.expectReadings([
      ("Run --[json](/ʤˈAsᵊn/)_out now.", "ɹˈʌn ʤˈAsᵊnˈWt nˈW.", "ɹˈʌn ʤˈAsᵊnˈWt nˈW."),
      ("See /[usr](/jˈuzəɹ/)2 here.", "sˈi jˈuzəɹtˈu hˈɪɹ.", "sˈiː jˈuzəɹtˈuː hˈɪə.")
    ])
  }

  /// The period that closes an abbreviation stays with a span on the
  /// abbreviation, as it always has: cut off, it is a full stop in front of
  /// the name (`dˈɑktəɹ. smˈɪθ`). The first three rows are unmoved; the
  /// third is an abbreviation by the period inside it. A sentence that ends
  /// on the abbreviation loses its pause the same way, and the caller's
  /// remedy is the fourth row's: the period inside the label and the
  /// phonemes. A span on the period itself is still cut out of its token
  /// (the last row was `ðə dˈɑt kˈɑm`).
  @Test func anAbbreviationsPeriodStaysWithItsSpan() {
    Self.expectReadings([
      ("Ask [Dr](/dˈɑktəɹ/). Smith now.", "ˈæsk dˈɑktəɹ smˈɪθ nˈW.", "ˈɑːsk dˈɑktəɹ smˈɪθ nˈW."),
      ("Call her [Ms](/mˈɪz/). She agreed.", "kˈɔl hɜɹ mˈɪz ʃˌi əɡɹˈid.", "kˈɔːl hɜː mˈɪz ʃˌiː əɡɹˈiːd."),
      ("The [U.S](/jˌuˈɛs/). said so.", "ðə jˌuˈɛs sˈɛd sˌO.", "ðə jˌuˈɛs sˈɛd sˌQ."),
      ("Call her [Ms.](/mˈɪz./) She agreed.", "kˈɔl hɜɹ mˈɪz. ʃˌi əɡɹˈid.", "kˈɔːl hɜː mˈɪz. ʃˌiː əɡɹˈiːd."),
      ("The x[.](/dˈɑt/) com.", "ði ˈɛksdˈɑt kˈɑm.", "ði ˈɛksdˈɑt kˈɒm.")
    ])
  }

  /// The period after a lone capital is not an abbreviation's. spaCy keeps
  /// it in the token in case the capital is an initial, and where the word
  /// ends a sentence it is the sentence's full stop, which the span took:
  /// `spˈAsˈɛks ðə nˈɛkst`, `ˈɛks hˌi spˈOk` and `ʤˈAzˈizˈi. hˌi`, the "Z"
  /// said twice as well. The cost is the last row: a span on an initial
  /// keeps its period too (`ʤˈA smˈɪθ` before), as "J. Smith" does unwrapped.
  @Test func aLoneCapitalsPeriodIsCutOffAndRead() {
    Self.expectReadings([
      ("It is from [SpaceX](/spˈAsˈɛks/). The next one flew.",
       "ˌɪt ɪz fɹʌm spˈAsˈɛks. ðə nˈɛkst wˈʌn flˈu.", "ˌɪt ɪz fɹɒm spˈAsˈɛks. ðə nˈɛkst wˈʌn flˈuː."),
      ("We met [Malcolm](/mˈælkəm/) [X](/ˈɛks/). He spoke.",
       "wˌi mˈɛt mˈælkəm ˈɛks. hˌi spˈOk.", "wˌiː mˈɛt mˈælkəm ˈɛks. hˌiː spˈQk."),
      ("I like [Jay-Z](/ʤˈAzˈi/). He raps.", "ˌI lˈIk ʤˈAzˈi. hˌi ɹˈæps.", "ˌI lˈIk ʤˈAzˈi. hˌiː ɹˈaps."),
      ("He is [J](/ʤˈA/). Smith.", "hˌi ɪz ʤˈA. smˈɪθ.", "hˌiː ɪz ʤˈA. smˈɪθ.")
    ])
  }

  /// A span that opens the text ends where its label does. The label was
  /// appended as bridged UTF-16 to a string that is UTF-8 from then on, so
  /// with any non-ASCII letter in it the span's end was recorded one unit
  /// short per such letter. "Niño" fell outside its own span and was read
  /// twice (`ɛl nˈinjO nˈinjO jˈɪɹ.`); the second row was `bijˈɑnsA tˈʊɹ.`.
  ///
  /// With the cut and the claim by overlap the readings no longer show it,
  /// so the tokens are read too: an end one unit short cuts the token where
  /// it already ends and leaves a piece of no text after the span.
  @Test func aSpanThatOpensTheTextEndsWhereItsLabelDoes() {
    Self.expectReadings([
      ("[El Niño](/ɛl nˈinjO/) year.", "ɛl nˈinjO jˈɪɹ.", "ɛl nˈinjO jˈɪə."),
      ("[Beyoncé](/bijˈɑnsA/)2024 tour.",
       "bijˈɑnsAtwˈɛnti twˈɛnti fˈɔɹ tˈʊɹ.", "bijˈɑnsAtwˈɛnti twˈɛnti fˈɔː tˈʊə."),
      ("[Beyoncé](/bijˈɑnsA/)\u{2019}s album is out.", "bijˈɑnsAz ˈælbəm ɪz ˈWt.", "bijˈɑnsAz ˈalbəm ɪz ˈWt.")
    ])
    let tokens = EnglishG2P(british: false).phonemize(text: "[Beyoncé](/bijˈɑnsA/)\u{2019}s album is out.").1
    #expect(tokens.map(\.text) == ["Beyoncé", "\u{2019}s", "album", "is", "out", "."])
  }

  /// A token no span cuts is not touched: only a piece is ever emptied. A
  /// hyphen that stands alone keeps its reading, and so does a token spaCy
  /// cut off itself against a span, where the reading is the letter the
  /// fallback names for "#" (unmoved, and not endorsed). And a span that
  /// ends the text is cut out of its token like any other.
  @Test func onlyATokenASpanCutsIsTouched() {
    Self.expectReadings([
      ("Up 5 - [ten](/tˈɛn/) - and more.", "ˌʌp fˈIv — tˈɛn — ænd mˈɔɹ.", "ˌʌp fˈIv — tˈɛn — and mˈɔː."),
      ("The [C](/sˈi/)# code.", "ðə sˈiˈɛks kˈOd.", "ðə sˈiwˈiː kˈQd."),
      ("See #[1](/wˈʌn/) now.", "sˈi ˈɛkswˈʌn nˈW.", "sˈiː wˈiːwˈʌn nˈW."),
      ("A next[word](/wˈɜɹd/)", "ɐ nˈɛkstwˈɜɹd", "ɐ nˈɛkstwˈɜɹd")
    ])
  }

  /// A stress or a number flag replaces nothing, so it cuts nothing: the
  /// token is still read as the one word it is, with the mark on the whole of
  /// it. Each reads as its unmarked row does, as it did. Cut, the first two
  /// read `wˌɜɹdnˈɛkst` and the x `ˈɛksfˈIv`. Nor does a stress claim a token
  /// it only overlaps, as a forced span does: the last row's "Yorker" keeps
  /// its stress (`jɔɹkəɹ` by overlap), as it did.
  @Test func aStressSpanCutsNothing() {
    Self.expectReadings([
      ("A [word](2)next.", "ɐ wˈɜɹdnɛkst.", "ɐ wˈɜːdnɛkst."),
      ("A [word](#a#)next.", "ɐ wˈɜɹdnɛkst.", "ɐ wˈɜːdnɛkst."),
      ("The [New Yor](-2)ker said.", "ðə nu jˈɔɹkəɹ sˈɛd.", "ðə njuː jˈɔːkə sˈɛd."),
      ("A wordnext.", "ɐ wˈɜɹdnɛkst.", "ɐ wˈɜːdnɛkst."),
      ("The x[-5](2) term.", "ði ˈɛks fˈIv tˈɜɹm.", "ði ˈɛks fˈIv tˈɜːm."),
      ("The x-5 term.", "ði ˈɛks fˈIv tˈɜɹm.", "ði ˈɛks fˈIv tˈɜːm.")
    ])
  }

  /// What a cut piece reads as is its own reading, and for these it is not
  /// the right one. They are pinned so they cannot drift, not endorsed.
  ///
  /// A clitic after a span reads as it already did where spaCy cuts it off
  /// itself: "[they](/ðˈA/)'ll" and "[Verizon](/…/)'ll" now agree, British
  /// `ˌiːl` and all, where the second had no clitic. `ForcedSpanPossessiveTests`
  /// pins the first and says why it is a fault of its own. A bare "s" is the
  /// letter: only the possessive is re-derived from the span's last sound.
  @Test func aCutPieceReadsAsItReadsAlone() {
    Self.expectReadings([
      ("[Verizon](/vəɹˈIzᵊn/)'ll go.", "vəɹˈIzᵊnəl ɡˌO.", "vəɹˈIzᵊnˌiːl ɡˌQ."),
      ("[they](/ðˈA/)'ll go.", "ðˈAəl ɡˌO.", "ðˈAˌiːl ɡˌQ."),
      ("[Verizon](/vəɹˈIzᵊn/)'ve gone.", "vəɹˈIzᵊnvˈiv ɡˈɔn.", "vəɹˈIzᵊnvˈA ɡˈɒn."),
      ("[they](/ðˈA/)'ve gone.", "ðˈAvˈiv ɡˈɔn.", "ðˈAvˈA ɡˈɒn."),
      ("[Verizon](/vəɹˈIzᵊn/)'re here.", "vəɹˈIzᵊnɹˌA hˈɪɹ.", "vəɹˈIzᵊnɹˌA hˈɪə."),
      ("A [word](/wˈɜɹd/)s here.", "ɐ wˈɜɹdˈɛs hˈɪɹ.", "ɐ wˈɜɹdˈɛs hˈɪə.")
    ])
  }

  /// A span that is a token, or several whole ones, is cut nowhere and reads
  /// as it did: set off by a space, before a hyphen or a possessive spaCy
  /// cuts itself, and over two words.
  @Test func aSpanThatFillsItsTokensIsUnmoved() {
    Self.expectReadings([
      ("A [word](/wˈɜɹd/) next.", "ɐ wˈɜɹd nˈɛkst.", "ɐ wˈɜɹd nˈɛkst."),
      ("A [word](/wˈɜɹd/)-era thing.", "ɐ wˈɜɹdˈɛɹə θˈɪŋ.", "ɐ wˈɜɹdˈɪəɹə θˈɪŋ."),
      ("The [dog](/dˈɔɡ/)'s bowl.", "ðə dˈɔɡz bˈOl.", "ðə dˈɔɡz bˈQl."),
      ("The [El Niño](/ɛl nˈinjO/) year.", "ði ɛl nˈinjO jˈɪɹ.", "ði ɛl nˈinjO jˈɪə.")
    ])
  }
}
