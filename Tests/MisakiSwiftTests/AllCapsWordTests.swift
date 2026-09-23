import Testing
@testable import MisakiSwift

/// An all-caps word of four letters or more, or an all-caps contraction, reads
/// as the word the lexicon knows even where the tagger calls it a proper noun.
///
/// spaCy's tagger is case-sensitive and tags nearly every token of an all-caps
/// headline NNP. Upstream sends an NNP token to the lowercase path only past
/// seven letters, so every shorter word gold lacks was spelled letter by
/// letter. That covered silver words ("RACED"), stem-derived words ("DETAILS"),
/// and gold words that carry no primary stress ("SHOULD", "YOU'RE"). Every
/// value below is the word's own lowercase reading, measured against the build
/// before the change.
struct AllCapsWordTests {

  /// The reported words. Each is in silver alone, which an NNP lookup skipped.
  /// Before: "RACED" `ˌɑɹˌAsˌiˌidˈi` / `ˌɑːˌAsˌiːˌiːdˈiː`, "PLACED"
  /// `pˌiˌɛlˌAsˌiˌidˈi`, and the rest spelled the same way.
  @Test func theReportedPastTensesReadAsWords() {
    let fixtures: [(word: String, american: String, british: String)] = [
      ("RACED", "ɹˈAst", "ɹˈAst"),
      ("PLACED", "plˈAst", "plˈAst"),
      ("TYPED", "tˈIpt", "tˈIpt"),
      ("NURSED", "nˈɜɹst", "nˈɜːst"),
      ("SCOPED", "skˈOpt", "skˈQpt"),
      ("CHASED", "ʧˈAst", "ʧˈAst")
    ]
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.word).0 == fixture.american,
              "wrong American reading for \(fixture.word)")
      #expect(british.phonemize(text: fixture.word).0 == fixture.british,
              "wrong British reading for \(fixture.word)")
    }
    #expect(american.phonemize(text: "HE RACED HOME").0 == "hˈi ɹˈAst hˈOm")
    #expect(british.phonemize(text: "HE RACED HOME").0 == "hˈiː ɹˈAst hˈQm")
  }

  /// The other two classes, in the headline shape that exposed them. "DETAILS"
  /// is in no American tier and derives from "detail". "SHOULD" is gold `ʃˌʊd`,
  /// and `lookup` spells an NNP gold word without primary stress. Before, the
  /// American line read `… ˌɛsˌAʧˌOjˌuˌɛldˈi ʃˈO mˈɔɹ dˌiˌitˌiˌAˌIˌɛlˈɛs`.
  @Test func stemDerivedAndUnstressedGoldWordsReadAsWords() {
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    #expect(american.phonemize(text: "THE APP SHOULD SHOW MORE DETAILS").0
            == "ði ˈæp ʃˈʊd ʃˈO mˈɔɹ dətˈAlz")
    #expect(british.phonemize(text: "THE APP SHOULD SHOW MORE DETAILS").0
            == "ði ˈap ʃˈʊd ʃˈQ mˈɔː dˈiːtAlz")
    #expect(american.phonemize(text: "NURSES CHASED THE TYPED NOTES").0
            == "nˈɜɹsᵻz ʧˈAst ðə tˈIpt nˈOts")
    #expect(american.phonemize(text: "TOKENS").0 == "tˈOkᵊnz")
    #expect(british.phonemize(text: "TOKENS").0 == "tˈQkᵊnz")
  }

  /// A possessive is measured by its base, so a word the base already reads
  /// takes the clitic. Before: "NASA'S" spelled N-A-S-A-S
  /// (`ˌɛnˌAˌɛsˌAˈɛs`), even though bare "NASA" read `nˈæsə`. Publishers write
  /// the curly apostrophe, which the tokenizer does not split off, so both
  /// spellings are pinned.
  @Test func aPossessiveFollowsItsBase() {
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    #expect(american.phonemize(text: "NASA'S").0 == "nˈæsəz")
    #expect(british.phonemize(text: "NASA'S").0 == "nˈasəz")
    #expect(american.phonemize(text: "NASA'S ROVER RACED THE CLOCK").0
            == "nˈæsəz ɹˈOvəɹ ɹˈAst ðə klˈɑk")
    #expect(american.phonemize(text: "NASA\u{2019}S ROVER").0 == "nˈæsəz ɹˈOvəɹ")
    #expect(british.phonemize(text: "NASA\u{2019}S ROVER").0 == "nˈasəz ɹˈQvə")
  }

  /// A contraction's clitic proves a word however short its host, because no
  /// acronym takes one. `'S` does only where gold lists the whole form, since
  /// it is the possessive too. Before: "YOU'RE" `wˌIˌOjˌuˌɑɹˈi`, "HE'D"
  /// `ˌAʧˌidˈi`, "SHE'S" `ˌɛsˌAʧˌiˈɛs`, and curly "IT’S" `ˌItˌiˈɛs` -- the
  /// most frequent spelled token in the measured corpus, 698 times.
  @Test func aContractionReadsAsItsWord() {
    let fixtures: [(text: String, american: String, british: String)] = [
      ("YOU'RE FIRED", "jˈʊɹ fˈIəɹd", "jˈɔː fˈIəd"),
      ("TRUMP SAYS HE'D SIGN", "tɹˈʌmp sˈɛz hˈid sˈIn", "tɹˈʌmp sˈɛz hˈiːd sˈIn"),
      ("SHE'S HERE", "ʃˈiz hˈɪɹ", "ʃˈiːz hˈɪə"),
      ("IT\u{2019}S TIME TO GO", "ˈɪts tˈIm tə ʤˌiˈO", "ˈɪts tˈIm tə ʤˌiːˈQ")
    ]
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "wrong American reading for \(fixture.text.debugDescription)")
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "wrong British reading for \(fixture.text.debugDescription)")
    }
  }

  /// Nothing the lexicon cannot read as a word is touched: an acronym it has
  /// no entry or stem for is spelled at any length, bare, in a headline and in
  /// prose. An acronym that folds to a gold word ("NASA", "ICE", "ARM") keeps
  /// that word, as it always did.
  @Test func acronymsKeepTheirReadings() {
    let fixtures: [(text: String, american: String, british: String)] = [
      ("FBI", "ˌɛfbˌiˈI", "ˌɛfbˌiːˈI"),
      ("NCAA", "ˌɛnsˌiˌAˈA", "ˌɛnsˌiːˌAˈA"),
      ("ESPN", "ˌiˌɛspˌiˈɛn", "ˌiːˌɛspˌiːˈɛn"),
      ("MSNBC", "ˌɛmˌɛsˌɛnbˌisˈi", "ˌɛmˌɛsˌɛnbˌiːsˈiː"),
      ("WWDC", "dˌʌbᵊljudˌʌbᵊljudˌisˈi", "dˌʌbᵊljuːdˌʌbᵊljuːdˌiːsˈiː"),
      ("THE FBI RAIDED HIS HOME", "ði ˌɛfbˌiˈI ɹˈAdᵻd hˈɪz hˈOm", "ði ˌɛfbˌiːˈI ɹˈAdɪd hˈɪz hˈQm"),
      ("The FBI said on Monday.", "ði ˌɛfbˌiˈI sˈɛd ˌɔn mˈʌndˌA.", "ði ˌɛfbˌiːˈI sˈɛd ˌɒn mˈʌndA."),
      ("NASA", "nˈæsə", "nˈasə"),
      ("ICE", "ˈIs", "ˈIs"),
      ("ARM", "ˈɑɹm", "ˈɑːm")
    ]
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "\(fixture.text.debugDescription) moved")
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "\(fixture.text.debugDescription) moved")
    }
  }

  /// The bound. Each three-letter acronym here would resolve to a word: "UPS",
  /// "IOS" and "SOS" through a stemmer ("up", "io", "so"), "WHO" as gold
  /// `who`. So a three-letter token stays with the tagger, and one headline
  /// shows both sides of the line.
  @Test func threeLettersIsStillTheTaggersCall() {
    let fixtures: [(text: String, american: String, british: String)] = [
      ("UPS", "jˌupˌiˈɛs", "jˌuːpˌiːˈɛs"),
      ("IOS", "ˌIˌOˈɛs", "ˌIˌQˈɛs"),
      ("SOS", "ˌɛsˌOˈɛs", "ˌɛsˌQˈɛs"),
      ("The WHO said on Monday.", "ðə dˌʌbᵊljuˌAʧˈO sˈɛd ˌɔn mˈʌndˌA.", "ðə dˌʌbᵊljuːˌAʧˈQ sˈɛd ˌɒn mˈʌndA."),
      ("UPS DRIVER PLACED ORDER", "jˌupˌiˈɛs dɹˈIvəɹ plˈAst ˈɔɹdəɹ", "jˌuːpˌiːˈɛs dɹˈIvə plˈAst ˈɔːdə")
    ]
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "\(fixture.text.debugDescription) moved")
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "\(fixture.text.debugDescription) moved")
    }
  }

  /// The bare-`-d` guard. `stem_ed` would derive "simd" and "wasd" from "sim"
  /// and "was", and prose writes both acronyms in capitals, so without the
  /// guard these sentences read "simmed" and "wuzzd". They are unchanged.
  @Test func aBareDIsNotAPastTense() {
    let fixtures: [(text: String, american: String, british: String)] = [
      ("The SIMD instructions are fast.",
       "ði ˌɛsˌIˌɛmdˈi ɪnstɹˈʌkʃənz ɑɹ fˈæst.",
       "ði ˌɛsˌIˌɛmdˈiː ɪnstɹˈʌkʃᵊnz ɑː fˈɑːst."),
      ("Use the WASD keys.",
       "jˈuz ðə dˌʌbᵊljuˌAˌɛsdˈi kˈiz.",
       "jˈuːz ðə dˌʌbᵊljuːˌAˌɛsdˈiː kˈiːz.")
    ]
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "\(fixture.text.debugDescription) moved")
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "\(fixture.text.debugDescription) moved")
    }
  }

  /// The predicate alone, independent of what the tagger calls any fixture
  /// above. Every positive test in this suite only reaches the new path while
  /// spaCy tags its token NNP, so this is what still holds if that changes.
  @Test func theBoundItself() {
    let lexicon = Lexicon(british: false)
    let fixtures: [(word: String, clears: Bool)] = [
      ("RACED", true),
      ("Raced", false),
      ("NASA'S", true),
      ("ADP'S", false),
      ("UPS", false),
      ("FBI", false),
      ("YOU'RE", true),
      ("HE'D", true),
      ("AREN'T", true),
      ("IT'S", true),
      ("UPS'S", false)
    ]

    for fixture in fixtures {
      #expect(lexicon.clearsTheAllCapsBound(fixture.word) == fixture.clears,
              "\(fixture.word) should \(fixture.clears ? "" : "not ")clear the bound")
    }
  }

  /// Known residual: a four-letter acronym that silver itself lists as a word,
  /// "cpus" and "leds". These were spelled before and are words now. Prose
  /// writes "CPUs" and "LEDs", which is not all caps and is unaffected, so only
  /// all-caps text reaches this. The values are pinned so they cannot drift
  /// silently. They are not endorsed.
  @Test func fourLetterAcronymsSilverListsAsWords() {
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)

    #expect(american.phonemize(text: "CPUS").0 == "sˈipˈʌs")
    #expect(british.phonemize(text: "CPUS").0 == "sˈiːpˈʌs")
    #expect(american.phonemize(text: "LEDS").0 == "lˈɛdz")
    #expect(british.phonemize(text: "LEDS").0 == "lˈɛdz")
  }
}
