import Testing
@testable import MisakiSwift

/// A run of capitals is tagged again from the same text in lower case.
///
/// spaCy tags nearly every token of an all-caps headline NNP or NN, and the
/// lexicon spells a short token so tagged: an NNP gold word with no primary
/// stress ("AT", "ON", "SO"), a gold entry keyed on the tag ("MY", "BY"), or
/// an initialism entry tagged a noun ("IT", "US"). The four-letter bound in
/// `Lexicon.clearsTheAllCapsBound` could not reach these, because length
/// cannot tell "MY APPS" from "US STOCKS". The lower-case tagger can, from
/// the sentence around them. Every "before" below is the build without it.
///
/// Each guard in `EnglishG2P.acceptsFoldedTag` is pinned by a sentence
/// that reads differently with that guard deleted; each test names its
/// guard, checked by deleting it.
struct AllCapsRunTests {

  private static func expectReadings(
    _ fixtures: [(text: String, american: String, british: String)],
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let american = EnglishG2P(british: false)
    let british = EnglishG2P(british: true)
    for fixture in fixtures {
      #expect(american.phonemize(text: fixture.text).0 == fixture.american,
              "American \(fixture.text.debugDescription)", sourceLocation: sourceLocation)
      #expect(british.phonemize(text: fixture.text).0 == fixture.british,
              "British \(fixture.text.debugDescription)", sourceLocation: sourceLocation)
    }
  }

  /// The reported class. Before, American: "HE TOLD US ABOUT IT AT THE
  /// MEETING" read `hˈi tˈOld jˌuˈɛs əbˈWt ˌItˈi ˈæt ...`, "MY PHONE IS AT
  /// HOME" read `... ˈɪz ˌAtˈi hˈOm ...`, and "MY" beside UPS `ˌɛmwˈI`.
  @Test func shortWordsInARunReadAsWords() {
    Self.expectReadings([
      ("HE TOLD US ABOUT IT AT THE MEETING",
       "hˈi tˈOld ˈʌs əbˈWt ˈɪt ˈæt ðə mˈiTɪŋ",
       "hˈiː tˈQld ˈʌs əbˈWt ˈɪt ˈat ðə mˈiːtɪŋ"),
      ("MY PHONE IS AT HOME ON THE TABLE",
       "mˈI fˈOn ˈɪz ˈæt hˈOm ˈɔn ðə tˈAbᵊl",
       "mˈI fˈQn ˈɪz ˈat hˈQm ˈɒn ðə tˈAbᵊl"),
      ("UPS WILL DELIVER MY PACKAGE ON MONDAY",
       "jˌupˌiˈɛs wˈɪl dəlˈɪvəɹ mˈI pˈækɪʤ ˈɔn mˈʌndˌA",
       "jˌuːpˌiːˈɛs wˈɪl dɪlˈɪvə mˈI pˈakɪʤ ˈɒn mˈʌndA")
    ])
  }

  /// The punctuation path. spaCy does not split an all-caps contraction, and
  /// the single token it sees instead can come back tagged as punctuation,
  /// which drops it from the audio. Before, "WON'T" here was an empty string
  /// (`pˈipᵊl  nˈid`).
  @Test func anAllCapsContractionIsNotDropped() {
    Self.expectReadings([
      ("AN OPTIONAL SUBSCRIPTION PROVIDES ACCESS TO MORE DATA, BUT MOST PEOPLE WON'T NEED IT.",
       "ɐn ˈɑpʃənᵊl səbskɹˈɪpʃən pɹəvˈIdz ˈæksˌɛs tə mˈɔɹ dˈATə, bˈʌt mˈOst pˈipᵊl wˈOnt nˈid ˈɪt.",
       "ɐn ˈɒpʃənᵊl səbskɹˈɪpʃᵊn pɹəvˈIdz ˈaksɛs tə mˈɔː dˈAtə, bˈʌt mˈQst pˈiːpᵊl wˈQnt nˈiːd ˈɪt.")
    ])
  }

  /// The 0.99 gate on gold's initialism entries. Without it each of these
  /// reads as the word: US as "us" (the tagger calls "us" PRP in all but
  /// the first), "touch id" as the id (spaCy splits it "i" + "d", and "i" is
  /// PRP), "the os update" as the bone, the SAT as "sat". All unchanged.
  @Test func anInitialismEntryNeedsAConfidentRetag() {
    Self.expectReadings([
      ("THE FBI SAYS AI IS CHANGING HOW US STOCKS TRADE",
       "ði ˌɛfbˌiˈI sˈɛz ˈAˌI ˈɪz ʧˈAnʤɪŋ hˈW jˌuˈɛs stˈɑks tɹˈAd",
       "ði ˌɛfbˌiːˈI sˈɛz ˈAˌI ˈɪz ʧˈAnʤɪŋ hˈW jˌuːˈɛs stˈɒks tɹˈAd"),
      ("A DWINDLING WATER SUPPLY FOR 40 MILLION PEOPLE IN THE WESTERN US.",
       "ɐ dwˈɪndᵊlɪŋ wˈɔTəɹ səplˈI fˈɔɹ fˈɔɹTi mˈɪljᵊn pˈipᵊl ɪn ðə wˈɛstəɹn jˌuˈɛs.",
       "ɐ dwˈɪndlɪŋ wˈɔːtə səplˈI fˈɔː fˈɔːti mˈɪljən pˈiːpᵊl ɪn ðə wˈɛstᵊn jˌuːˈɛs."),
      ("DONALD TRUMP HAS SAID THAT THE US WOULD APPOINT A NEW AI TSAR",
       "dˈɑnəld tɹˈʌmp hˈæz sˈɛd ðˈæt ðə jˌuˈɛs wˈʊd əpˈYnt ɐ nˈu ˈAˌI zˈɑɹ",
       "dˈɒnᵊld tɹˈʌmp hˈaz sˈɛd ðˈat ðə jˌuːˈɛs wˈʊd əpˈYnt ɐ njˈuː ˈAˌI zˈɑː"),
      ("IT'S BASICALLY LIKE YOUR IT DEPARTMENT, CORPORATE INFORMATION",
       "ˈɪts bˈAsəkᵊli lˈIk jˈʊɹ ˌItˈi dəpˈɑɹtmənt, kˈɔɹpəɹət ˌɪnfəɹmˈAʃən",
       "ˈɪts bˈAsɪkli lˈIk jˈɔː ˌItˈiː dɪpˈɑːtmᵊnt, kˈɔːpəɹət ˌɪnfəmˈAʃᵊn"),
      ("APPLE RELEASES IOS 27 WITH NEW TOUCH ID FEATURES",
       "ˈæpᵊl ɹəlˈisᵻz ˌIˌOˈɛs twˈɛnti sˈɛvən wˈɪð nˈu tˈʌʧ ˌIdˈi fˈiʧəɹz",
       "ˈapᵊl ɹɪlˈiːsɪz ˌIˌQˈɛs twˈɛnti sˈɛvᵊn wˈɪð njˈuː tˈʌʧ ˌIdˈiː fˈiːʧəz"),
      ("SO WHAT HAPPENED TO THE OS UPDATE?",
       "sˈO wˈʌt hˈæpənd tə ði ˌOˈɛs ˈʌpdˌAt?",
       "sˈQ wˈɒt hˈapᵊnd tə ði ˌQˈɛs ˈʌpdAt?"),
      ("THE UNIVERSITY SHOULD NOT BRING BACK THE SAT REQUIREMENT FOR ADMISSION.",
       "ðə jˌunəvˈɜɹsəTi ʃˈʊd nˈɑt bɹˈɪŋ bˈæk ði ˌɛsˌAtˈi ɹəkwˈIəɹmᵊnt fˈɔɹ ədmˈɪʃən.",
       "ðə jˌuːnɪvˈɜːsɪti ʃˈʊd nˈɒt bɹˈɪŋ bˈak ði ˌɛsˌAtˈiː ɹɪkwˈIəmᵊnt fˈɔː ədmˈɪʃᵊn.")
    ])
  }

  /// The derivation guard: "UPS", "SOS" and "NAS" reach a word only through
  /// `stem_s` ("up", "so", "na"), and without the guard read "ups", "sos",
  /// "nuz". All unchanged.
  @Test func aShortWordReachedOnlyByDerivationStaysSpelled() {
    Self.expectReadings([
      ("UPS WILL DELIVER MY PACKAGE ON MONDAY",
       "jˌupˌiˈɛs wˈɪl dəlˈɪvəɹ mˈI pˈækɪʤ ˈɔn mˈʌndˌA",
       "jˌuːpˌiːˈɛs wˈɪl dɪlˈɪvə mˈI pˈakɪʤ ˈɒn mˈʌndA"),
      ("EMERGENCY SOS, FIND MY, AND MESSAGES VIA SATELLITE",
       "əmˈɜɹʤənsi ˌɛsˌOˈɛs, fˈInd mˈI, ˈænd mˈɛsɪʤᵻz vˈIə sˈæTᵊlˌIt",
       "ɪmˈɜːʤᵊnsi ˌɛsˌQˈɛs, fˈInd mˈI, ˈand mˈɛsɪʤɪz vˈIə sˈatəlIt"),
      ("BROWSING MY NAS VIA THE FILES APP WAS SPEEDY",
       "bɹˈWzɪŋ mˈI ˌɛnˌAˈɛs vˈIə ðə fˈIlz ˈæp wˈʌz spˈidi",
       "bɹˈWzɪŋ mˈI ˌɛnˌAˈɛs vˈIə ðə fˈIlz ˈap wˈɒz spˈiːdi")
    ])
  }

  /// The promotion guard. Folded, "$50K" is one token "50k", so "K" borrows
  /// its CD and the currency lands after it ("fifty K dollars"); "xi" is NNP
  /// in lower case, and NNP spells unstressed gold "xi" (`ˌɛksˈI`). Both
  /// unchanged. The name after XI is a separate residual, spelled before and
  /// after.
  @Test func aRetagNeverPromotesToANameOrANumber() {
    Self.expectReadings([
      ("STAFF GET $50K BONUSES",
       "stˈæf ɡˈɛt fˈɪfti dˈɑləɹz kˈA bˈOnəsᵻz",
       "stˈɑːf ɡˈɛt fˈɪfti dˈɒləz kˈA bˈQnəsɪz"),
      ("TALK TO XI JINPING AND DONALD TRUMP",
       "tˈɔk tə zˈI ʤˌAˌIˌɛnpˌiˌIˌɛnʤˈi ˈænd dˈɑnəld tɹˈʌmp",
       "tˈɔːk tə zˈI ʤˌAˌIˌɛnpˌiːˌIˌɛnʤˈiː ˈand dˈɒnᵊld tɹˈʌmp")
    ])
  }

  /// Three more tags the re-tag leaves alone, each pinned where it would move.
  /// The hyphen rule: lower case reads "a" as DT, the article, but a capital
  /// joined by a hyphen is the letter (`dˈʌbᵊlɐ` without it). The heteronym
  /// rule: "CLOSE" is NNP in capitals and JJ in lower case, and the button
  /// closes rather than being near (`klˈOs` without it). The capitals-apart
  /// rule: gold lists "AI" apart from British "ai", the sloth, and tagged NN
  /// the possessive went to lower case (`ˈɑːiz`). It stays spelled, a
  /// residual of its own. All unchanged.
  @Test func tagsTheRetagLeavesAlone() {
    Self.expectReadings([
      ("THE UNDERWRITERS EXPECT A DOUBLE-A RATING FROM MOODY'S.",
       "ði ˈʌndəɹɹˌITəɹz ɪkspˈɛkt ɐ dˈʌbᵊlˈA ɹˈATɪŋ fɹˈʌm mˈudiz.",
       "ði ˈʌndəɹˌItəz ɪkspˈɛkt ɐ dˈʌbᵊlˈA ɹˈAtɪŋ fɹˈɒm mˈuːdɪz."),
      ("THE PEAK MEMORY FOOTPRINT CLOSE BUTTON",
       "ðə pˈik mˈɛməɹi fˈʊtpɹˌɪnt klˈOz bˈʌtᵊn",
       "ðə pˈiːk mˈɛməɹi fˈʊtpɹɪnt klˈQz bˈʌtᵊn"),
      ("THE AI'S ANSWER WAS WRONG",
       "ði ˌAˌIˈɛs ˈænsəɹ wˈʌz ɹˈɔŋ",
       "ði ˌAˌIˈɛs ˈɑːnsə wˈɒz ɹˈɒŋ")
    ])
  }

  /// Plain regression pins: the lower-case tagger keeps "the it department"
  /// and "ios" NNP by itself, so no single guard decides these. Prose is not
  /// a run: acronyms side by side, or one emphasized word. All unchanged.
  @Test func unchangedReadings() {
    Self.expectReadings([
      ("THE IT DEPARTMENT IS OVERWHELMED BY TICKETS",
       "ði ˌItˈi dəpˈɑɹtmənt ˈɪz ˌOvəɹhwˈɛlmd bˈI tˈɪkəts",
       "ði ˌItˈiː dɪpˈɑːtmᵊnt ˈɪz ˌQvəwˈɛlmd bˈI tˈɪkɪts"),
      ("The FBI said the US and AI firms met at SXSW.",
       "ði ˌɛfbˌiˈI sˈɛd ðə jˌuˈɛs ænd ˈAˌI fˈɜɹmz mˈɛt æt ˌɛsˌɛksˌɛsdˈʌbᵊlju.",
       "ði ˌɛfbˌiːˈI sˈɛd ðə jˌuːˈɛs and ˈAˌI fˈɜːmz mˈɛt at ˌɛsˌɛksˌɛsdˈʌbᵊljuː."),
      ("Prices for RAM and SSD storage rose in the US and EU.",
       "pɹˈIsᵻz fɔɹ ɹˈæm ænd ˌɛsˌɛsdˈi stˈɔɹɪʤ ɹˈOz ɪn ðə jˌuˈɛs ænd ˌijˈu.",
       "pɹˈIsɪz fɔː ɹˈam and ˌɛsˌɛsdˈiː stˈɔːɹɪʤ ɹˈQz ɪn ðə jˌuːˈɛs and ˌiːjˈuː."),
      ("This is VERY important to me.",
       "ðˌɪs ɪz vˈɛɹi ɪmpˈɔɹtᵊnt tə mˌi.",
       "ðˌɪs ɪz vˈɛɹi ɪmpˈɔːtᵊnt tə mˌiː.")
    ])
  }

  /// The acceptance rules on their own, independent of what the tagger calls
  /// any sentence above. The two defensive rules are pinned only here.
  @Test func acceptanceRules() {
    let g2p = EnglishG2P(british: true)
    func accepts(_ token: String, _ capitals: String, _ folded: String, _ confidence: Float = 1) -> Bool {
      g2p.acceptsFoldedTag(folded, confidence: confidence, for: token, taggedInCapitals: capitals)
    }

    #expect(accepts("AT", "NNP", "IN"))
    #expect(accepts("WON'T", "-LRB-", "MD"))
    #expect(!accepts("AT", "NNP", "NNP"), "an unchanged tag")
    #expect(!accepts("-SIZED", "NN", "JJ"), "not a word's shape")
    #expect(!accepts("SO", "JJ", "RB"), "only a noun tag is the capitals' doing")
    #expect(!accepts("XI", "NN", "NNP"), "never promoted to a name")
    #expect(!accepts("BONUSES", "NNS", "CD"), "never promoted to a number")
    #expect(!accepts("HOME", "NN", "."), "never demoted to punctuation")
    #expect(!accepts("CLOSE", "NNP", "JJ"), "a heteronym")
    #expect(!accepts("AI", "NNP", "NN"), "capitals gold reads apart")
    #expect(!accepts("UPS", "NNP", "NNS"), "a word only by derivation")
    #expect(accepts("ADS", "NNP", "NNS"), "silver lists \"ads\" itself")
    #expect(accepts("US", "NNP", "PRP", 0.995))
    #expect(!accepts("US", "NNP", "PRP", 0.98), "an initialism entry, unsure")
    #expect(!accepts("US", "NNP", "PRP", .nan), "an initialism entry, no confidence")
  }

  /// What counts as a run, independent of any tagger.
  @Test func runMembership() {
    let words: Set<String> = ["TOLD", "HOME", "STOCKS"]
    func members(_ text: String) -> Set<Int> {
      AllCapsRun.members(of: text.split(separator: " ").map(String.init), isWord: words.contains)
    }

    #expect(members("HE TOLD US") == [0, 1, 2])
    // Digits and punctuation neither join nor break a run.
    #expect(members("HE TOLD , 27 US") == [0, 1, 4])
    // A lower-case letter ends one.
    #expect(members("HE TOLD us AT HOME") == [0, 1, 3, 4])
    // A row of initialisms has no word, and a word alone is not a run.
    #expect(members("RAM / SSD") == [])
    #expect(members("the US EU EU treaty") == [])
    #expect(members("very TOLD indeed") == [])
    // One-letter tokens join a run but do not make one.
    #expect(members("A STOCKS") == [])
    #expect(members("I TOLD A STORY") == [0, 1, 2, 3])
  }

  /// Folding keeps every token findable. Each span, in the folded text,
  /// holds the folded token, and each token the folded text re-tokenizes to
  /// sits at its own span -- where lower case changes a length ("İ" is two
  /// UTF-16 units folded), where a flag or skin tone is split, and where
  /// folding splits ("WON'T") or merges ("$50K") tokens.
  @Test func foldingKeepsTokensFindable() throws {
    let tokenizer = try SpacyTokenizer()
    func slice(_ text: String, _ span: Range<Int>) -> String {
      let utf16 = Array(text.utf16)
      return String(decoding: utf16[span], as: UTF16.self)
    }
    for text in [
      "İSTANBUL TOLD US",
      "🇺🇸 HE TOLD US 👍🏽 TODAY",
      "MOST PEOPLE WON'T NEED IT.",
      "STAFF GET $50K BONUSES",
      "U.S. STOCKS FELL  -A LOT"
    ] {
      let tokens = tokenizer.tokenize(text)
      let folded = AllCapsRun.folding(tokens, of: text, members: Set(tokens.indices))
      for (token, span) in zip(tokens, folded.spans) {
        #expect(slice(folded.text, span) == AllCapsRun.caseFolded(token.text), "\(text.debugDescription)")
      }
      let refolded = tokenizer.tokenize(folded.text)
      for (token, span) in zip(refolded, AllCapsRun.utf16Spans(of: refolded, in: folded.text)) {
        #expect(slice(folded.text, span) == token.text, "\(text.debugDescription)")
      }
    }
  }

  /// Prose capitalizes "I" on its own and in "I'm", so the fold keeps it.
  @Test func caseFoldingKeepsThePronounI() {
    #expect(AllCapsRun.caseFolded("I") == "I")
    #expect(AllCapsRun.caseFolded("I'M") == "I'm")
    #expect(AllCapsRun.caseFolded("I\u{2019}LL") == "I\u{2019}ll")
    #expect(AllCapsRun.caseFolded("IT") == "it")
    #expect(AllCapsRun.caseFolded("IPHONE") == "iphone")
    #expect(AllCapsRun.caseFolded("WON'T") == "won't")
  }

  /// A confidence is the softmax probability of the chosen tag: one per
  /// token, in (0, 1].
  @Test func everyTagHasAConfidence() throws {
    let trace = try SpacyEnglishTagger().trace("HE TOLD US ABOUT IT, AND IT WAS NEWS.")
    #expect(trace.confidences.count == trace.tokens.count)
    #expect(trace.confidences.allSatisfy { $0 > 0 && $0 <= 1 })
  }
}
