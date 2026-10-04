import MLXUtilsLibrary
import Testing
@testable import MisakiSwift

/// A dotted acronym's speller reads the figures in what it is handed.
///
/// `getNNP` spells a word by its letters and drops every other character
/// without a trace. It was handed every word of a dotted acronym's shape (a
/// letter, a dot inside, no more than two characters between dots), and a
/// figure beside a letter has that shape: "v0.5" was `vˈi`, "0.5x" `ˈɛks`,
/// "No.5" `ˌɛnˈO`. `Lexicon.getDottedAcronym` reads such a word now: the
/// letters spelled as they were, a figure as a figure, and a symbol the
/// lexicon has a word for as that word.
///
/// Upstream misaki narrows the shape instead, to letters and dots
/// (`word.replace('.', '').isalpha()`). That was built and measured first,
/// and is not what this port can take: subtokenized, a token's dots are marks
/// here and a part with no lexicon reading takes its group to the fallback,
/// so "S.&P." read `ˈɛs.ænd pˈi.`, "Ch.3" `ʧˈɑŋ` and "BA.5" `bˈɑ fˈIv`. Every
/// "before" below was measured at `113ff75`.
struct DottedAcronymTests {

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

  /// The shape, which both callers ask for: a letter, a dot inside the word,
  /// and no more than two characters between dots, whatever they are.
  @Test func theShapeIsALetterADotInsideAndShortParts() {
    let shaped = [
      "U.S.", "U.S", "e.g.", "Ph.D.", "M.R.C.S.", "a..b", "É.U.",
      "v0.5", "0.5x", "No.5", "1.5e", "H.26", "v1.2b", "-0.6b",
      "U.S.'s", "O.K.'d", "C.-C.", "S.&P.", "XX.X%", "A.+B."
    ]
    for word in shaped {
      #expect(Lexicon.isDottedAcronym(word), "\(word) has the shape")
    }
    // No letter; three characters between dots; no dot inside.
    for word in ["25.10", "1.5", "example.com", "U.S.Army", "H.264", "1.5e5", "Mr.", "US", ".a", "a", "", "..."] {
      #expect(!Lexicon.isDottedAcronym(word), "\(word) does not have the shape")
    }
  }

  /// A token of the shape. Each kept its letters and lost its figure: `vˈi`,
  /// `ˈɛks`, `ˌɛnˈO`, `ˈAʧ`, `ˈɛf`, `vˌibˈi`, `sˌiˈAʧ` and `bˌiˈA`. The
  /// letters read as they did, spelled, whatever the lexicon makes of them
  /// as a word ("no", "bah").
  @Test func aFigureBesideALetterIsRead() {
    Self.expectReadings([
      ("They shipped v0.5 today.",
       "ðˌA ʃˈɪpt vˈi zˈɪɹO pYnt fˈIv tədˈA.", "ðˌA ʃˈɪpt vˈiː zˈɪəɹQ pYnt fˈIv tədˈA."),
      ("It ran 0.5x faster.",
       "ˌɪt ɹˈæn zˈɪɹO pYnt fˈIv ˈɛks fˈæstəɹ.", "ˌɪt ɹˈan zˈɪəɹQ pYnt fˈIv ˈɛks fˈɑːstə."),
      ("See No.5 today.", "sˈi ˌɛnˈO fˈIv tədˈA.", "sˈiː ˌɛnˈQ fˈIv tədˈA."),
      ("They use H.26 video.", "ðˌA jˈuz ˈAʧ twˈɛnti sˈɪks vˈɪdiO.", "ðˌA jˈuːz ˈAʧ twˈɛnti sˈɪks vˈɪdɪQ."),
      ("See Phase F.2 today.", "sˈi fˈAz ˈɛf tˈu tədˈA.", "sˈiː fˈAz ˈɛf tˈuː tədˈA."),
      ("Use v1.2b today.", "jˈuz vˈi wˈʌn pYnt tˈu bˈi tədˈA.", "jˈuːz vˈiː wˈʌn pYnt tˈuː bˈiː tədˈA."),
      ("See Ch.3 for details.", "sˈi sˌiˈAʧ θɹˈi fɔɹ dətˈAlz.", "sˈiː sˌiːˈAʧ θɹˈiː fɔː dˈiːtAlz."),
      ("The BA.5 variant spread.", "ðə bˌiˈA fˈIv vˈɛɹiənt spɹˈɛd.", "ðə bˌiːˈA fˈIv vˈɛːɹɪənt spɹˈɛd.")
    ])
  }

  /// A longer token, which is not the shape itself. A subtoken group tries
  /// every slice of itself, and a slice was: "1.5e" of "1.5e5" (`ˈi fˈIv`,
  /// and a plus sign in front went with the mantissa), "0.5x" of "USB0.5x"
  /// (`jˌuˌɛsbˈi ˈɛks`), "9.0b" of "9.0b1" (`bˈi wˈʌn`) and "-0.6b" of
  /// "parakeet-en-0.6b" (`ˈɛn bˈi`). In that last slice the hyphen is a
  /// joiner and not a sign; only a figure that heads its group has one.
  @Test func aSliceOfAGroupReadsItsFigure() {
    Self.expectReadings([
      ("It moved 1.5e5 today.",
       "ˌɪt mˈuvd wˈʌn pYnt fˈIv ˈi fˈIv tədˈA.", "ˌɪt mˈuːvd wˈʌn pYnt fˈIv ˈiː fˈIv tədˈA."),
      ("It moved +1.5e5 today.",
       "ˌɪt mˈuvd plˈʌs wˈʌn pYnt fˈIv ˈi fˈIv tədˈA.", "ˌɪt mˈuːvd plˈʌs wˈʌn pYnt fˈIv ˈiː fˈIv tədˈA."),
      ("It uses USB0.5x today.",
       "ˌɪt jˈuzᵻz jˌuˌɛsbˈi zˈɪɹO pYnt fˈIv ˈɛks tədˈA.", "ˌɪt jˈuːzɪz jˌuːˌɛsbˈiː zˈɪəɹQ pYnt fˈIv ˈɛks tədˈA."),
      ("Use coremltools 9.0b1 today.",
       "jˈuz kˈɔɹəmtˌulz nˈIn pYnt zˈɪɹO bˈi wˈʌn tədˈA.", "jˈuːz kˈɔːmltuːlz nˈIn pYnt zˈɪəɹQ bˈiː wˈʌn tədˈA."),
      ("Load parakeet-en-0.6b today.",
       "lˈOd pˈɛɹəkˌitˈɛn zˈɪɹO pYnt sˈɪks bˈi tədˈA.", "lˈQd pˈaɹəkiːtˈɛn zˈɪəɹQ pYnt sˈɪks bˈiː tədˈA.")
    ])
  }

  /// Whatever the tagger called the token. A token of the shape is never cut,
  /// so it kept the tagger's tag, and under punctuation it was its own dots:
  /// `wˌʌz ɪt .?` (three times), `ˈOnli . ɹəmˈAnd.` and `.tˈOkᵊn pɹˈɑmpts
  /// hˈɛld.` One whose figure stands in front of its letters is a number
  /// now, as a figure cut from a token is, and one that holds a figure
  /// behind a letter a word.
  @Test func aTokenOfTheShapeIsReadWhateverTheTaggerCalledIt() {
    Self.expectReadings([
      ("Was it v2.0?", "wˌʌz ɪt vˈi tˈu pYnt zˈɪɹO?", "wˌɒz ɪt vˈiː tˈuː pYnt zˈɪəɹQ?"),
      ("Was it 0.5x?", "wˌʌz ɪt zˈɪɹO pYnt fˈIv ˈɛks?", "wˌɒz ɪt zˈɪəɹQ pYnt fˈIv ˈɛks?"),
      ("Was it JN.1?", "wˌʌz ɪt ʤˌAˈɛn wˈʌn?", "wˌɒz ɪt ʤˌAˈɛn wˈʌn?"),
      ("Only pp.12 remained.", "ˈOnli pˌipˈi twˈɛlv ɹəmˈAnd.", "ˈQnli pˌiːpˈiː twˈɛlv ɹɪmˈAnd."),
      ("~6.5K-token prompts held.",
       "sˈɪks pYnt fˈIv kˈAtˈOkᵊn pɹˈɑmpts hˈɛld.", "sˈɪks pYnt fˈIv kˈAtˈQkᵊn pɹˈɒmpts hˈɛld.")
    ])
  }

  /// The same, under every tag `retokenize` reads as punctuation or as a
  /// dash: the token comes back whole and unread. One whose figure stands
  /// in front of its letters is a number under any tag, whatever marks open
  /// it. One that holds a figure behind a letter is a noun under those tags
  /// and keeps a word's or a number's own, so that a currency sign in front
  /// of it finds what the tagger found. One with no figure in it keeps the
  /// tag it had.
  @Test func aTokenOfTheShapeThatHoldsAFigureIsReTaggedOverEveryTag() {
    let g2p = EnglishG2P(british: false)
    func retagged(_ text: String, under tag: String) -> (tag: String?, phonemes: String?, text: String?) {
      let token = MToken(
        text: text, tokenRange: text.startIndex..<text.endIndex,
        tag: SpacyEnglishTagger.lexicalClass(for: tag), whitespace: ""
      )
      var pennTags: PennTagMap = [ObjectIdentifier(token): tag]
      let whole = g2p.retokenize([token], pennTags: &pennTags).first as? MToken
      return (whole.flatMap { pennTags[ObjectIdentifier($0)] }, whole?.phonemes, whole?.text)
    }
    let marks = [".", ",", ":", "-LRB-", "-RRB-", "``", "''", "NFP", "HYPH"]
    for tag in marks + ["SYM", "NN", "NNP", "UH", "CD"] {
      for text in ["0.5x", "1.5B", "-1.5x", "+1.5B", "-.5x", "~.5x", "#1.x"] {
        let result = retagged(text, under: tag)
        #expect(result.text == text, "\(text) under \(tag) was cut")
        #expect(result.phonemes == nil, "\(text) under \(tag) was read as a mark")
        #expect(result.tag == "CD", "\(text) under \(tag) is not CD")
      }
      for text in ["v2.0", "pp.12", "No.5"] {
        let result = retagged(text, under: tag)
        #expect(result.text == text, "\(text) under \(tag) was cut")
        #expect(result.phonemes == nil, "\(text) under \(tag) was read as a mark")
        #expect(result.tag == (marks.contains(tag) ? "NN" : tag), "\(text) under \(tag) is \(result.tag ?? "nil")")
      }
    }
    #expect(retagged("U.S.", under: "NNP").tag == "NNP")
    #expect(retagged("e.g.", under: "FW").tag == "FW")
    #expect(retagged("U.S.", under: ".").tag == ".")
  }

  /// The reading is rated by its least sure piece, and the letters are a
  /// spelling's: no better than `getNNP`'s 3, and never the fallback's 1.
  @Test func theReadingIsRatedAsASpellingIs() {
    let tokens = EnglishG2P(british: false).phonemize(text: "They shipped v0.5 today.").1
    let figure = tokens.first { $0.text == "v0.5" }
    #expect(figure?.phonemes == "vˈi zˈɪɹO pYnt fˈIv")
    #expect(figure?.`_`.rating == 3)
  }

  /// A figure that heads its token is read as a head is: it keeps its sign
  /// (`ˈɛks` alone before), and a zero in front of it is no code's ("zero
  /// seven five" is what a figure that is no head would be). A file's version
  /// keeps its figure, the extension still spelled (`vˌipˌiwˈI`), and a
  /// version's wildcard was `ˈɛks` alone. A mark with no reading in front of
  /// the figure does not stop it heading: "~.5x" was `.` and is "point
  /// five", where the ".5" of "No.5", after letters, is "five".
  @Test func aSignAWildcardAndAnExtensionAreRead() {
    Self.expectReadings([
      ("It moved -1.5x today.",
       "ˌɪt mˈuvd mˈInəs wˈʌn pYnt fˈIv ˈɛks tədˈA.", "ˌɪt mˈuːvd mˈInəs wˈʌn pYnt fˈIv ˈɛks tədˈA."),
      ("It is 07.5x here.", "ˌɪt ɪz sˈɛvən pYnt fˈIv ˈɛks hˈɪɹ.", "ˌɪt ɪz sˈɛvᵊn pYnt fˈIv ˈɛks hˈɪə."),
      ("It is ~.5x here.", "ˌɪt ɪz pYnt fˈIv ˈɛks hˈɪɹ.", "ˌɪt ɪz pYnt fˈIv ˈɛks hˈɪə."),
      ("Run v2.py today.", "ɹˈʌn vˈi tˈu pˌiwˈI tədˈA.", "ɹˈʌn vˈiː tˈuː pˌiːwˈI tədˈA."),
      ("Use TensorFlow 2.x today.", "jˈus tˈɛnsəɹflˌO tˈu ˈɛks tədˈA.", "jˈuːs tˈɛnsəflˌQ tˈuː ˈɛks tədˈA.")
    ])
  }

  /// A symbol the lexicon has a word for went the way a figure did: "XX.X%"
  /// was `ˌɛksˌɛksˈɛks`, "%.1f" `ˈɛf`, "S.&P." `ˌɛspˈi` and "R.&D." `ˌɑɹdˈi`.
  @Test func aSymbolWithAWordIsRead() {
    Self.expectReadings([
      ("It grew XX.X% today.", "ˌɪt ɡɹˈu ˌɛksˌɛksˈɛks pəɹsˈɛnt tədˈA.", "ˌɪt ɡɹˈuː ˌɛksˌɛksˈɛks pəsˈɛnt tədˈA."),
      ("The format is %.1f here.",
       "ðə fˈɔɹmˌæt ɪz pəɹsˈɛnt wˈʌn ˈɛf hˈɪɹ.", "ðə fˈɔːmat ɪz pəsˈɛnt wˈʌn ˈɛf hˈɪə."),
      ("The S.&P. 500 rose today.",
       "ði ˈɛs ænd pˈi fˈIv hˈʌndɹəd ɹˈOz tədˈA.", "ði ˈɛs and pˈiː fˈIv hˈʌndɹəd ɹˈQz tədˈA."),
      ("Its R.&D. budget grew.", "ˌɪts ˈɑɹ ænd dˈi bˈʌʤət ɡɹˈu.", "ˌɪts ˈɑː and dˈiː bˈʌʤɪt ɡɹˈuː.")
    ])
  }

  /// A word with neither in it reads exactly as it did: an acronym, and one
  /// with an apostrophe or a hyphen in it, whose letters are all that is
  /// spelled (the clitic's too: "U-K-S"). The last row is not the shape,
  /// "-led" being three letters, and reads its dots as marks, as it did.
  @Test func aWordWithNoFigureOrSymbolIsSpelledAsItWas() {
    Self.expectReadings([
      ("The U.S. and the U.K. agreed.", "ðə jˌuˈɛs ænd ðə jˌukˈA əɡɹˈid.", "ðə jˌuːˈɛs and ðə jˌuːkˈA əɡɹˈiːd."),
      ("See e.g. this at 5 p.m. today.",
       "sˈi ˌiʤˈi ðɪs æt fˈIv pˌiˈɛm tədˈA.", "sˈiː ˌiːʤˈiː ðɪs at fˈIv pˌiːˈɛm tədˈA."),
      ("He holds a Ph.D. in it.", "hˌi hˈOldz ɐ pˌiˌAʧdˈi ɪn ɪt.", "hˌiː hˈQldz ɐ pˌiːˌAʧdˈiː ɪn ɪt."),
      ("J.R.R. Tolkien wrote it.", "ʤˌAˌɑɹˈɑɹ tˈOkiən ɹˈOt ɪt.", "ʤˌAˌɑːˈɑː tˈɒlkɪən ɹˈQt ɪt."),
      ("She O.K.'d the plan.", "ʃˌi ˌOkˌAdˈi ðə plˈæn.", "ʃˌiː ˌQkˌAdˈiː ðə plˈan."),
      ("Chiu, C.-C., wrote it.", "ʧˈiˌu, sˌisˈi, ɹˈOt ɪt.", "ʧˈiːuː, sˌiːsˈiː, ɹˈQt ɪt."),
      ("The U.S.-U.K. deal held.", "ðə jˌuˌɛsjˌukˈA dˈil hˈɛld.", "ðə jˌuːˌɛsjˌuːkˈA dˈiːl hˈɛld."),
      ("The U.K.\u{2019}s economy grew.", "ðə jˌukˌAˈɛs ikˈɑnəmi ɡɹˈu.", "ðə jˌuːkˌAˈɛs ɪkˈɒnəmi ɡɹˈuː."),
      ("A U.S.-led force came.", "ɐ jˈu.ˈɛs.lˈɛd fˈɔɹs kˈAm.", "ɐ jˈuː.ˈɛs.lˈɛd fˈɔːs kˈAm.")
    ])
  }

  /// A word with a letter and a dot inside it reaches no special case but
  /// this one, whether or not it has the shape. The "vs" case below it
  /// matches the end of a word, so a slice that ends that way under a
  /// preposition's tag would be "versus", its figure gone. The tagger calls
  /// a glued "1.25vs" a noun or a number in every sentence tried, so the slice
  /// is handed to the lexicon here as the group walk hands it over. A closing
  /// dot is no dot inside: "vs." is still "versus".
  @Test func aDottedWordReachesNoOtherSpecialCase() {
    let lexicon = EnglishG2P(british: false).lexicon
    func reading(_ text: String) -> String? {
      let slice = MToken(text: text, tokenRange: text.startIndex..<text.endIndex, tag: .preposition, whitespace: "")
      return lexicon.transcribe(slice, pennTag: "IN", ctx: TokenContext()).0
    }
    #expect(reading("vs") == "vˈɜɹsəs")
    #expect(reading("vs.") == "vˈɜɹsəs")
    #expect(reading("1.25vs") == nil)
  }
}
