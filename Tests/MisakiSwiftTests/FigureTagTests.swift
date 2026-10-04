import MLXUtilsLibrary
import Testing
@testable import MisakiSwift

/// A figure is a number whatever the tagger called its token.
///
/// A subtoken takes the tag of the spaCy token it was cut from, and only a
/// run of bare digits was re-tagged `CD`. The subtokenizer keeps a sign, a
/// point and a comma inside a figure ("-10.25", "1,250"), so such a figure
/// was the tagger's, and the tagger decides by the sentence. Called
/// punctuation, the figure was read as the marks in it: its own point, its
/// comma, or nothing. Called a hyphen it was the pause of a dash, and called
/// anything but a number it lost the currency sign in front of it. Upstream
/// misaki has the same branch (`tk.tag in PUNCT_TAGS`) and re-tags nothing;
/// reading the figure there is a deliberate divergence. Every "before" below
/// was measured at `113ff75` with the dotted-acronym reader applied.
struct FigureTagTests {

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

  /// The test itself: what the subtokenizer's number pattern cuts. Digits,
  /// with the commas and points it keeps among and in front of them, ending
  /// on a digit, and the one hyphen it keeps in front. A numeral that is no
  /// digit is cut alone and is one too, as it was ("½").
  @Test func aFigureIsWhatTheNumberPatternCuts() {
    let figures = ["5", "10.25", "-10.25", "-3", "1,250", "0.000000", "1,234,567.89", "1.2.3", "1.5,2", ".5", "-.5", ",5", "½"]
    for subtoken in figures {
      #expect(EnglishG2P.isFigure(subtoken), "\(subtoken) is a figure")
    }
    for subtoken in ["-", "", ".", ",", "5x", "x5", "1e5", "--5", "+5", "\u{2212}5", "5-", "5%", "5.", "5,"] {
      #expect(!EnglishG2P.isFigure(subtoken), "\(subtoken) is no figure")
    }
  }

  /// Whatever the tagger called the token: every tag `retokenize` reads as
  /// punctuation or as a dash, and a word's. The sentences below reach only
  /// the tags the tagger happens to give them, so the token is handed over
  /// here under each tag in turn, and comes back unread and a number.
  @Test func aFigureIsReTaggedOverEveryTag() {
    let g2p = EnglishG2P(british: false)
    let tags = [
      ".", ",", ":", "-LRB-", "-RRB-", "``", "''", "\"\"", "NFP", "HYPH", "SYM", "$", "#",
      "NN", "NNS", "NNP", "JJ", "RB", "FW", "UH", "LS", "XX", "ADD", "CD"
    ]
    for tag in tags {
      for text in ["-10.25", "1,250", "-3", ".5", ",5"] {
        let token = MToken(
          text: text, tokenRange: text.startIndex..<text.endIndex,
          tag: SpacyEnglishTagger.lexicalClass(for: tag), whitespace: ""
        )
        var pennTags: PennTagMap = [ObjectIdentifier(token): tag]
        let figure = g2p.retokenize([token], pennTags: &pennTags).first as? MToken
        #expect(figure?.text == text, "\(text) under \(tag) is not one subtoken")
        #expect(figure?.phonemes == nil, "\(text) under \(tag) was read as a mark")
        #expect(figure.flatMap { pennTags[ObjectIdentifier($0)] } == "CD", "\(text) under \(tag) is not CD")
      }
    }
  }

  /// A signed figure that joins the group before it keeps the tagger's tag,
  /// and one after a space, or after a mark with a reading, is re-tagged:
  /// what stands between is the whitespace of the group's last subtoken.
  @Test func aSignedFigureIsLeftToTheTaggerOnlyWhereItJoinsAGroup() {
    let g2p = EnglishG2P(british: false)
    func tagOfTheFigure(after text: String, whitespace: String) -> String? {
      let source = text + whitespace + "-3"
      let first = MToken(
        text: text, tokenRange: source.startIndex..<source.index(source.startIndex, offsetBy: text.count),
        tag: SpacyEnglishTagger.lexicalClass(for: "NN"), whitespace: whitespace
      )
      let figure = MToken(
        text: "-3", tokenRange: source.index(source.endIndex, offsetBy: -2)..<source.endIndex,
        tag: SpacyEnglishTagger.lexicalClass(for: ":"), whitespace: ""
      )
      var pennTags: PennTagMap = [ObjectIdentifier(first): "NN", ObjectIdentifier(figure): ":"]
      let words = g2p.retokenize([first, figure], pennTags: &pennTags)
      let last = (words.last as? [MToken])?.last ?? (words.last as? MToken)
      return last.flatMap { pennTags[ObjectIdentifier($0)] }
    }
    // Glued to a word, it joins that word's group and stays the tagger's.
    #expect(tagOfTheFigure(after: "x", whitespace: "") == ":")
    // After a space it heads a group of its own, whatever stood before it.
    #expect(tagOfTheFigure(after: "x", whitespace: " ") == "CD")
    #expect(tagOfTheFigure(after: "x2", whitespace: " ") == "CD")
  }

  /// A signed figure the tagger called punctuation (`-RRB-`, `:`, `.`, `NFP`,
  /// `-LRB-` and ` `` ` below). The first was `ˌɪt mˈuvd . tədˈA.`, its own
  /// point, and the others nothing at all: `ˌɪt mˈuvd tədˈA.`, `ðə skˈɔɹ
  /// wʌz .`, `ɪz ði ˈænsəɹ.`, `ˌɪt mˈuvd "".` and `ʧˈAnʤ: pəɹsˈɛnt, ðˈɛn mˈɔɹ.`
  @Test func aSignedFigureCalledPunctuationIsRead() {
    Self.expectReadings([
      ("It moved -10.25 today.",
       "ˌɪt mˈuvd mˈInəs tˈɛn pYnt tˈu fˈIv tədˈA.", "ˌɪt mˈuːvd mˈInəs tˈɛn pYnt tˈuː fˈIv tədˈA."),
      ("It moved -3 today.", "ˌɪt mˈuvd mˈInəs θɹˈi tədˈA.", "ˌɪt mˈuːvd mˈInəs θɹˈiː tədˈA."),
      ("The score was -10.", "ðə skˈɔɹ wʌz mˈInəs tˈɛn.", "ðə skˈɔː wɒz mˈInəs tˈɛn."),
      ("-3 is the answer.", "mˈInəs θɹˈi ɪz ði ˈænsəɹ.", "mˈInəs θɹˈiː ɪz ði ˈɑːnsə."),
      ("It moved \"-14\".", "ˌɪt mˈuvd \"mˈInəs fˌɔɹtˈin\".", "ˌɪt mˈuːvd \"mˈInəs fˌɔːtˈiːn\"."),
      ("Change: -11%, then more.",
       "ʧˈAnʤ: mˈInəs əlˈɛvᵊn pəɹsˈɛnt, ðˈɛn mˈɔɹ.", "ʧˈAnʤ: mˈInəs ɪlˈɛvᵊn pəsˈɛnt, ðˈɛn mˈɔː.")
    ])
  }

  /// It needs no sign. A grouped figure was its comma (`ˌɪt tˈʊk , ˈɛmz`),
  /// a decimal after a joining hyphen its point (`ʤˌipˌitˈi..`), and the
  /// mantissa of an exponent its point too (`(.ˈi plˈʌs zˈɪɹO zˈɪɹO` and
  /// `.ˈi plˈʌs zˈɪɹO fˈɔɹ`).
  @Test func anUnsignedFigureCalledPunctuationIsRead() {
    Self.expectReadings([
      ("It took ~1,250 ms today.",
       "ˌɪt tˈʊk wˈʌn θˈWzᵊnd tˈu hˈʌndɹəd fˈɪfti ˈɛmz tədˈA.",
       "ˌɪt tˈʊk wˈʌn θˈWzᵊnd tˈuː hˈʌndɹəd fˈɪfti ˈɛmz tədˈA."),
      ("They shipped GPT-14.96.",
       "ðˌA ʃˈɪpt ʤˌipˌitˈifˌɔɹtˈin pYnt nˈIn sˈɪks.", "ðˌA ʃˈɪpt ʤˌiːpˌiːtˈiːfˌɔːtˈiːn pYnt nˈIn sˈɪks."),
      ("Perfect accuracy (0.000000e+00 max diff).",
       "pˈɜɹfəkt ˈækjəɹəsi (zˈɪɹO pYnt zˈɪɹO zˈɪɹO zˈɪɹO zˈɪɹO zˈɪɹO zˈɪɹO ˈi plˈʌs zˈɪɹO zˈɪɹO mˈæks dˈɪf).",
       "pˈɜːfɪkt ˈakjʊɹəsi (zˈɪəɹQ pYnt zˈɪəɹQ zˈɪəɹQ zˈɪəɹQ zˈɪəɹQ zˈɪəɹQ zˈɪəɹQ ˈiː plˈʌs zˈɪəɹQ zˈɪəɹQ mˈaks dˈɪf)."),
      ("It moved 999.99e+04 today.",
       "ˌɪt mˈuvd nˈIn hˈʌndɹəd nˈIndi nˈIn pYnt nˈIn nˈIn ˈi plˈʌs zˈɪɹO fˈɔɹ tədˈA.",
       "ˌɪt mˈuːvd nˈIn hˈʌndɹəd nˈInti nˈIn pYnt nˈIn nˈIn ˈiː plˈʌs zˈɪəɹQ fˈɔː tədˈA.")
    ])
  }

  /// What is glued behind the figure is read after it. The figure used to
  /// stand alone as its mark, and now heads the group: `.kˈA` and
  /// `pəɹsˈɛnt` before. Under a hyphen's tag the figure was the dash token:
  /// "A -8% drop." was `ɐ —pəɹsˈɛnt dɹˈɑp.`.
  @Test func whatFollowsTheFigureIsReadAfterIt() {
    Self.expectReadings([
      ("It moved -10.25k today.",
       "ˌɪt mˈuvd mˈInəs tˈɛn pYnt tˈu fˈIv kˈA tədˈA.", "ˌɪt mˈuːvd mˈInəs tˈɛn pYnt tˈuː fˈIv kˈA tədˈA."),
      ("It fell -3% today.", "ˌɪt fˈɛl mˈInəs θɹˈi pəɹsˈɛnt tədˈA.", "ˌɪt fˈɛl mˈInəs θɹˈiː pəsˈɛnt tədˈA."),
      ("A -8% drop.", "ɐ mˈInəs ˈAt pəɹsˈɛnt dɹˈɑp.", "ɐ mˈInəs ˈAt pəsˈɛnt dɹˈɒp.")
    ])
  }

  /// A currency sign is kept by the figure after it. The amount's token is a
  /// noun to the tagger in the first sentence, and anything but a number's
  /// tag dropped the currency: "…forty five point six seven", no "dollars".
  /// "$-1" was "minus one", and "€.5" "point five". An amount spaCy does not
  /// cut is a token of a dotted acronym's shape, kept whole: under its noun's
  /// tag "$1.5B" was `bˈi` with no "dollars", where "$1.5M", which spaCy
  /// cuts, had them, and so has one that opens on a sign or a point
  /// ("$+1.5B"). One that holds its figure behind a letter is no amount
  /// ("$No.5" was `ˌɛnˈO`).
  @Test func aFigureAfterACurrencySignIsAnAmount() {
    Self.expectReadings([
      ("It cost $12,345.67 today.",
       "ˌɪt kˈɔst twˈɛlv θˈWzᵊnd θɹˈi hˈʌndɹəd fˈɔɹTi fˈIv dˈɑləɹz ænd sˈɪksti sˈɛvən sˈɛnts tədˈA.",
       "ˌɪt kˈɒst twˈɛlv θˈWzᵊnd θɹˈiː hˈʌndɹəd fˈɔːti fˈIv dˈɒləz and sˈɪksti sˈɛvᵊn sˈɛnts tədˈA."),
      ("It cost $-1 today.", "ˌɪt kˈɔst mˈInəs wˈʌn dˈɑləɹ tədˈA.", "ˌɪt kˈɒst mˈInəs wˈʌn dˈɒlə tədˈA."),
      ("It cost \u{20AC}.5 today.", "ˌɪt kˈɔst fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst fˈɪfti sˈɛnts tədˈA."),
      ("It cost $1.5B today.",
       "ˌɪt kˈɔst wˈʌn pYnt fˈIv bˈi dˈɑləɹz tədˈA.", "ˌɪt kˈɒst wˈʌn pYnt fˈIv bˈiː dˈɒləz tədˈA."),
      ("It cost $1.5M today.",
       "ˌɪt kˈɔst wˈʌn pYnt fˈIv ˈɛm dˈɑləɹz tədˈA.", "ˌɪt kˈɒst wˈʌn pYnt fˈIv ˈɛm dˈɒləz tədˈA."),
      ("It cost $+1.5B today.",
       "ˌɪt kˈɔst plˈʌs wˈʌn pYnt fˈIv bˈi dˈɑləɹz tədˈA.", "ˌɪt kˈɒst plˈʌs wˈʌn pYnt fˈIv bˈiː dˈɒləz tədˈA."),
      ("It cost $-.5B today.",
       "ˌɪt kˈɔst mˈInəs pYnt fˈIv bˈi dˈɑləɹz tədˈA.", "ˌɪt kˈɒst mˈInəs pYnt fˈIv bˈiː dˈɒləz tədˈA."),
      ("It cost $No.5 today.", "ˌɪt kˈɔst ˌɛnˈO fˈIv tədˈA.", "ˌɪt kˈɒst ˌɛnˈQ fˈIv tədˈA.")
    ])
  }

  /// And the figure after the amount is not one. The currency is given to
  /// one figure (`CurrencyFractionTests`), so a signed figure across a mark
  /// from an amount reads as it did while the tagger's noun kept the currency
  /// off it: re-tagged with the currency still standing, these were "minus
  /// two dollars and thirty cents percent" and "minus ten dollars and fifty
  /// cents".
  @Test func aSignedFigureAfterAnAmountIsNotAnAmount() {
    Self.expectReadings([
      ("The stock closed at $120.50 (-2.3%) today.",
       "ðə stˈɑk klˈOzd æt wˈʌn hˈʌndɹəd twˈɛnti dˈɑləɹz ænd fˈɪfti sˈɛnts (mˈInəs tˈu pYnt θɹˈi pəɹsˈɛnt) tədˈA.",
       "ðə stˈɒk klˈQzd at wˈʌn hˈʌndɹəd twˈɛnti dˈɒləz and fˈɪfti sˈɛnts (mˈInəs tˈuː pYnt θɹˈiː pəsˈɛnt) tədˈA."),
      ("It cost $5; -10.5 was the change.",
       "ˌɪt kˈɔst fˈIv dˈɑləɹz; mˈInəs tˈɛn pYnt fˈIv wʌz ðə ʧˈAnʤ.",
       "ˌɪt kˈɒst fˈIv dˈɒləz; mˈInəs tˈɛn pYnt fˈIv wɒz ðə ʧˈAnʤ.")
    ])
  }

  /// A figure the tagger already called a number, and one it called a noun,
  /// read as they did.
  @Test func aFigureTheTaggerReadIsUnchanged() {
    Self.expectReadings([
      ("It moved -2 today.", "ˌɪt mˈuvd mˈInəs tˈu tədˈA.", "ˌɪt mˈuːvd mˈInəs tˈuː tədˈA."),
      ("It moved 10.25 today.", "ˌɪt mˈuvd tˈɛn pYnt tˈu fˈIv tədˈA.", "ˌɪt mˈuːvd tˈɛn pYnt tˈuː fˈIv tədˈA.")
    ])
  }

  /// A figure that opens on a point is one too. After a letter run of three
  /// the point closes nothing the dotted-acronym reader takes, and the tagger
  /// called the figures of "XBB.1.16" punctuation: `ˌɛksbˌibˈi..`. A bare
  /// ".5" was `. ɪz ði ˈænsəɹ.`
  @Test func aFigureThatOpensOnAPointIsRead() {
    Self.expectReadings([
      ("The XBB.1.16 variant spread.",
       "ði ˌɛksbˌibˈi wˈʌn sˌɪkstˈin vˈɛɹiənt spɹˈɛd.", "ði ˌɛksbˌiːbˈiː wˈʌn sˌɪkstˈiːn vˈɛːɹɪənt spɹˈɛd."),
      (".5 is the answer.", "pYnt fˈIv ɪz ði ˈænsəɹ.", "pYnt fˈIv ɪz ði ˈɑːnsə.")
    ])
  }

  /// A re-tagged figure keeps its lexicon reading when the adjoining letters
  /// need fallback. At 3617c2d the format precision and backticked figures
  /// disappeared with those letters; FallbackFigureTests pins the repair.
  @Test func aFigureGluedToAPartTheFallbackTakesIsStillRead() {
    Self.expectReadings([
      ("It took %.4fs, then more.", "ˌɪt tˈʊk pəɹsˈɛnt fˈɔɹ ˈɛfs, ðˈɛn mˈɔɹ.", "ˌɪt tˈʊk pəsˈɛnt fˈɔː ˈɛfs, ðˈɛn mˈɔː."),
      ("The format is %.2fs here.", "ðə fˈɔɹmˌæt ɪz pəɹsˈɛnt tˈu ˈɛfs hˈɪɹ.", "ðə fˈɔːmat ɪz pəsˈɛnt tˈuː ˈɛfs hˈɪə."),
      ("We get `1.23ms`, `1.05ms` and `0.86ms` latency.",
       "wˌi ɡɛt wˈʌn pYnt tˈu θɹˈi ˈɛmz, wˈʌn pYnt zˈɪɹO fˈIv ˈɛmz ænd zˈɪɹO pYnt ˈAt sˈɪks ˈɛmz lˈAtᵊnsi.",
       "wˌiː ɡɛt wˈʌn pYnt tˈuː θɹˈiː ˈɛmz, wˈʌn pYnt zˈɪəɹQ fˈIv ˈɛmz and zˈɪəɹQ pYnt ˈAt sˈɪks ˈɛmz lˈAtᵊnsi.")
    ])
  }

  /// What the re-tag does not reach, pinned as it reads. spaCy takes "(-8"
  /// for an emoticon, so the hyphen is no longer in front of its token and
  /// the subtokenizer cuts it off the figure: the sign is lost. And a signed
  /// figure that joins the group before it is left to the tagger, because
  /// the lexicon takes a hyphen for a sign only on the head of a group:
  /// re-tagged, the "-3" of "5+-3" has no reading and takes the group to the
  /// fallback (`ˈimˌɛk`).
  @Test func whatTheReTagDoesNotReach() {
    Self.expectReadings([
      ("The value (-8) is low.", "ðə vˈælju (ˈAt) ɪz lˈO.", "ðə vˈaljuː (ˈAt) ɪz lˈQ."),
      ("It is 5+-3 today.", "ˌɪt ɪz fˈIv plˈʌs tədˈA.", "ˌɪt ɪz fˈIv plˈʌs tədˈA.")
    ])
  }
}
