import Testing
@testable import MisakiSwift

/// A contraction the lexicon does not list whole reads as its host followed by
/// the clitic, the clitic taken from the lexicon's own contractions.
///
/// Neither lexicon has `'ve` or `'re`, and the British one has no `'ll`. spaCy
/// splits "should've" into "should" + "'ve", so the grouped word missed whole
/// and its clitic missed alone, and the BART fallback read the spelling
/// ("shoald"). `'re` reached the gold word "re" instead (`ɹˌA`, "ray"). An
/// all-caps contraction is one spaCy token, and was spelled letter by letter
/// whenever its lowercase was not a whole gold entry. Every "before" below was
/// measured at `ac479cf`.
struct ContractionCliticTests {

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

  /// The reported mixed-case sentences. Before, American: `ʃˈOld`, `wˈʊldv`,
  /// `mˈʌstv`, `mˈAv`, `hid` (the 've dropped), `wɛɹˈɛv`, `θˈɛɹˌɛv`, `wˈʌtv`,
  /// `wˈuv`, and every 're a "-ray": `hˌuɹˌA`, `wˌʌtɹˌA`, `wˌɛɹɹˌA`,
  /// `ðˌɛɹɹˌA`, `hˌWɹˌA`, `wˌIɹˌA`. "that'd" was `ðˈætd`: the listed `'d`
  /// fused into the stop.
  @Test func mixedCaseContractionsReadAsHostAndClitic() {
    Self.expectReadings([
      ("I should've known better.", "ˌI ʃˌʊdəv nˈOn bˈɛTəɹ.", "ˌI ʃˌʊdəv nˈQn bˈɛtə."),
      ("She would've said so.", "ʃˌi wʊdəv sˈɛd sˌO.", "ʃˌiː wʊdəv sˈɛd sˌQ."),
      ("They must've left early.", "ðˌA mˈʌstəv lˈɛft ˈɜɹli.", "ðˌA mˈʌstəv lˈɛft ˈɜːli."),
      ("It may've been a mistake.", "ˌɪt mˈAəv bɪn ɐ məstˈAk.", "ˌɪt mˈAəv biːn ɐ mɪstˈAk."),
      ("He'd've been there.", "hˌidəv bɪn ðˈɛɹ.", "hˌiːdəv biːn ðˈɛː."),
      ("Where've you been?", "wˌɛɹəv ju bˌɪn?", "wˌɛːv juː bˌiːn?"),
      ("There've been reports.", "ðˌɛɹəv bɪn ɹəpˈɔɹts.", "ðˌɛːv biːn ɹɪpˈɔːts."),
      ("What've they done?", "wˌʌTəv ðA dˈʌn?", "wˌɒtəv ðA dˈʌn?"),
      ("Who've you seen?", "hˌuv ju sˈin?", "hˌuːv juː sˈiːn?"),
      ("Who're you?", "hˌuəɹ ju?", "hˌuːə juː?"),
      ("What're the odds?", "wˌʌTəɹ ði ˈɑdz?", "wˌɒtə ði ˈɒdz?"),
      ("Where're you going?", "wˌɛɹəɹ ju ɡˈOɪŋ?", "wˌɛːɹə juː ɡˈQɪŋ?"),
      ("There're many.", "ðˌɛɹəɹ mˈɛni.", "ðˌɛːɹə mˈɛni."),
      ("How're you?", "hˌWəɹ ju?", "hˌWə juː?"),
      ("Why're you here?", "wˌIəɹ ju hˈɪɹ?", "wˌIə juː hˈɪə?"),
      ("That'd be great.", "ðˈæTəd bi ɡɹˈAt.", "ðˈatəd biː ɡɹˈAt."),
      ("What'd she say?", "wˌʌTəd ʃi sˈA?", "wˌɒtəd ʃiː sˈA?"),
      ("I wouldn't've known.", "ˌI wˈʊdᵊntəv nˈOn.", "ˌI wˈʊdᵊntəv nˈQn.")
    ])
  }

  /// The British lexicon lists no `'ll`, so every British "-'ll" went to the
  /// fallback, which read "that" and "this" with a θ: `θˈatᵊl`, `θˌɛɹˈɛl`,
  /// `θˈɪzᵊl`. "daren't" was `dˈɛːɹənt`. American is unchanged in all four.
  @Test func britishWillAndNotFollowTheLexicon() {
    Self.expectReadings([
      ("That'll be the day.", "ðˈætəl bi ðə dˈA.", "ðˈatᵊl biː ðə dˈA."),
      ("There'll be time.", "ðˌɛɹəl bi tˈIm.", "ðˌɛːl biː tˈIm."),
      ("This'll work.", "ðˌɪsəl wˈɜɹk.", "ðˌɪsᵊl wˈɜːk."),
      ("You daren't go.", "jˌu dˈɛɹnt ɡˌO.", "jˌuː dˈɛːnt ɡˌQ.")
    ])
  }

  /// All caps, where spaCy leaves a contraction whole. Each was spelled: "WE
  /// SHOULD'VE KNOWN" was `wˈi ˌɛsˌAʧˌOjˌuˌɛldˌivˌiˈi nˈOn`, "THAT'LL"
  /// `tˌiˌAʧˌAtˌiˌɛlˈɛl`, "DAREN'T" `dˌiˌAˌɑɹˌiˌɛntˈi`, and "DOGS'" (a plural
  /// possessive, whose merged form the all-caps rule in `isKnown` accepted as
  /// a letter run) `dˌiˌOʤˌiˈɛs`. Each now reads as its lowercase does, with
  /// the stress an all-caps word always takes.
  @Test func allCapsContractionsReadAsWords() {
    Self.expectReadings([
      ("WE SHOULD'VE KNOWN", "wˈi ʃˈʊdəv nˈOn", "wˈiː ʃˈʊdəv nˈQn"),
      ("THAT'LL BE THE DAY", "ðˈætəl bˈi ðə dˈA", "ðˈatᵊl bˈiː ðə dˈA"),
      ("WHO'LL STOP THE RAIN", "hˈuəl stˈɑp ðə ɹˈAn", "hˈuːl stˈɒp ðə ɹˈAn"),
      ("WHAT'RE THE ODDS", "wˈʌTəɹ ði ˈɑdz", "wˈɒtə ði ˈɒdz"),
      ("THERE'D BE NO POINT", "ðˈɛɹd bˈi nˈO pˈYnt", "ðˈɛːd bˈiː nˈQ pˈYnt"),
      ("THIS'LL WORK", "ðˈɪsəl wˈɜɹk", "ðˈɪsᵊl wˈɜːk"),
      ("WHO'VE WON", "hˈuv wˈʌn", "hˈuːv wˈʌn"),
      ("HE'D'VE KNOWN", "hˈidəv nˈOn", "hˈiːdəv nˈQn"),
      ("DAREN'T", "dˈɛɹnt", "dˈɛːnt"),
      ("THE DOGS' DINNER", "ðə dˈɔɡz dˈɪnəɹ", "ðə dˈɒɡz dˈɪnə")
    ])
  }

  /// Contractions that already read correctly, byte-identical before and
  /// after: two whole gold forms, the listed American `'ll` and `'d`, which
  /// are appended exactly as the grouped word appended them, and the pronoun
  /// forms gold lists whole.
  @Test func contractionsThatAlreadyWorkedAreUnchanged() {
    Self.expectReadings([
      ("I could've known.", "ˌI kʊdəv nˈOn.", "ˌI kʊdəv nˈQn."),
      ("It might've been.", "ˌɪt mˈITəv bˌɪn.", "ˌɪt mˈItəv bˌiːn."),
      ("Who'll stop the rain?", "hˌuəl stˈɑp ðə ɹˈAn?", "hˌuːl stˈɒp ðə ɹˈAn?"),
      ("What'll it be?", "wˌʌtəl ɪt bˈi?", "wˌɒtᵊl ɪt bˈiː?"),
      ("Who'd know?", "hˌud nˈO?", "hˌuːd nˈQ?"),
      ("It'd help.", "ˈɪTəd hˈɛlp.", "ˈɪtəd hˈɛlp."),
      ("Where'd he go?", "wˌɛɹd hi ɡˌO?", "wˌɛːd hiː ɡˌQ?"),
      ("You're right.", "jˌʊɹ ɹˈIt.", "jˌɔː ɹˈIt."),
      ("They've left.", "ðˌAv lˈɛft.", "ðˌAv lˈɛft."),
      ("the dogs' dinner", "ðə dˈɔɡz dˈɪnəɹ", "ðə dˈɒɡz dˈɪnə")
    ])
  }

  /// `'ve` fuses into a vowel-final pronoun or wh-word, as gold's `I've`,
  /// `we've`, `they've` and `you've` do, but stays syllabic after a modal
  /// whatever its final sound, as gold's `could've`, `might've` and British
  /// `may've` do. The lexicon marks the modal by listing its negative
  /// (`mayn't`), so American "may've" (`mˈAv`) now matches the British entry.
  /// "How've" had dropped its clitic in American (`hW`). "Why've" was already
  /// fused and only its stress moved: the host's own `wˌI` replaces the
  /// fallback's primary stress, as gold's `who'd` (`hˌud`) has it.
  @Test func aModalKeepsItsSyllabicHave() {
    Self.expectReadings([
      ("They may've left.", "ðˌA mˈAəv lˈɛft.", "ðˌA mˈAəv lˈɛft."),
      ("How've you been?", "hˌWv ju bˌɪn?", "hˌWv juː bˌiːn?"),
      ("Why've they gone?", "wˌIv ðA ɡˈɔn?", "wˌIv ðA ɡˈɒn?")
    ])
  }

  /// A schwa-final host supplies the clitic's schwa. The lexicon writes two
  /// schwas in a row only across a
  /// hyphen (`kala-azar`), and a clitic is no second word. "NASA'll" was the
  /// fallback's `nˈAsᵊl` in mixed case and spelled in all caps.
  @Test func aSchwaFinalHostSuppliesTheClitic() {
    Self.expectReadings([
      ("NASA'll launch it.", "nˈæsəl lˈɔnʧ ɪt.", "nˈasəl lˈɔːnʧ ɪt."),
      ("NASA'LL LAUNCH IT", "nˈæsəl lˈɔnʧ ˈɪt", "nˈasəl lˈɔːnʧ ˈɪt")
    ])
  }

  /// Apostrophes that are not these clitics are untouched, and an acronym in
  /// a plural possessive keeps its letters: the trailing-apostrophe path only
  /// stops the merged form being spelled, and the base is then read by the
  /// rules it always had (three letters stays the tagger's call).
  @Test func otherApostrophesAreUntouched() {
    Self.expectReadings([
      ("O'Brien said so.", "ˈObɹiən sˈɛd sˌO.", "ˈQbɹɪɛn sˈɛd sˌQ."),
      ("Rock'n'roll lives.", "ɹˌɑkᵊnɹl lˈɪvz.", "ɹˈɒkᵊnɹQl lˈɪvz."),
      ("THE FBI' CASE", "ði ˌɛfbˌiˈI kˈAs", "ði ˌɛfbˌiːˈI kˈAs"),
      ("UPS' TRUCKS", "jˌupˌiˈɛs tɹˈʌks", "jˌuːpˌiːˈɛs tɹˈʌks")
    ])
  }

  /// Every clitic reading is a difference between two lexicon entries, so
  /// these values are what the lexicon says, not what this file says. The
  /// `'re` reading comes from `doer` over `do`; the other vowel-final `-er`
  /// pairs are checked to agree, so it is the suffix, not one word's quirk.
  @Test func everyReadingIsDerivedFromTheLexicon() {
    let american = Lexicon(british: false).contractions
    #expect(american.fusedHave == "v")
    #expect(american.syllabicHave == "əv")
    #expect(american.syllabicAre == "əɹ")
    #expect(american.listedWill == "əl")
    #expect(american.fusedWill == "l")
    #expect(american.syllabicWill == "ᵊl")
    #expect(american.listedWould == "d")
    #expect(american.syllabicWould == "əd")
    #expect(american.rhoticNot == "nt")
    #expect(american.syllabicNot == "ᵊnt")
    #expect(american.linking == "")

    let british = Lexicon(british: true).contractions
    #expect(british.fusedHave == "v")
    #expect(british.syllabicHave == "əv")
    #expect(british.syllabicAre == "ə")
    #expect(british.listedWill == nil)
    #expect(british.fusedWill == "l")
    #expect(british.syllabicWill == "ᵊl")
    #expect(british.listedWould == "d")
    #expect(british.syllabicWould == "əd")
    #expect(british.rhoticNot == "nt")
    #expect(british.syllabicNot == "ᵊnt")
    #expect(british.linking == "ɹ")

    for (lexicon, isBritish) in [(american, false), (british, true)] {
      let golds = DataResourcesUtil.loadGold(british: isBritish)
      for (stem, suffixed) in [("free", "freer"), ("new", "newer"), ("high", "higher"), ("few", "fewer")] {
        let derived = (golds[suffixed] as? String).flatMap { whole in
          (golds[stem] as? String).flatMap { ContractionClitics.suffix(of: whole, over: $0) }
        }
        #expect(derived == lexicon.syllabicAre, "\(suffixed) over \(stem) disagrees with doer over do")
      }
      #expect(["may", "could", "might", "must", "should", "would"].allSatisfy(lexicon.auxiliaries.contains))
      #expect(!["who", "how", "why", "we", "they", "you", "there"].contains(where: lexicon.auxiliaries.contains))
    }
  }

  /// The split: `n't` whole, otherwise the text after the last apostrophe, so
  /// a double contraction rests on its first. `'s` belongs to `stem_s`, and
  /// nothing without a letter before the apostrophe is a host.
  @Test func theSplit() {
    #expect(ContractionClitics.split("should've")! == ("should", "ve"))
    #expect(ContractionClitics.split("HE'D'VE")! == ("HE'D", "ve"))
    #expect(ContractionClitics.split("daren't")! == ("dare", "n't"))
    #expect(ContractionClitics.split("wouldn't've")! == ("wouldn't", "ve"))
    #expect(ContractionClitics.split("dog's") == nil)
    #expect(ContractionClitics.split("'ve") == nil)
    #expect(ContractionClitics.split("O'Brien") == nil)
    #expect(ContractionClitics.split("rock'n'roll") == nil)
  }
}
