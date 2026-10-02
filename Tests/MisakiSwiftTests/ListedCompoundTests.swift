import Testing
@testable import MisakiSwift

/// A hyphenated compound the lexicon lists whole reads from its own entry
/// where a part of it has no reading of its own.
///
/// spaCy splits "sci-fi" into "sci", "-", "fi". `retokenize` gave the hyphen
/// an empty reading, a token with a reading stands alone, and so the merged
/// lookup that finds gold's `sci-fi` was never made: each half went to the
/// BART fallback, which read the spelling. Every "before" below was measured
/// at `ca35bc2`.
struct ListedCompoundTests {

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

  /// The reported word, in the casings prose writes it. Before, American:
  /// `sˈIfˈI` for "Sci-Fi" and `sˈIfˈi` ("sigh-fee") for "sci-fi" and
  /// "Sci-fi"; British `sˈiːfˈiː` ("see-fee") and `sˈIfˈiː`. In capitals it
  /// was spelled, `ˌɛssˌiˈIˌɛfˈI`. "Sci-fi" is the casing that opens a
  /// sentence, which `growDictionary` did not key.
  @Test func sciFiReadsFromItsOwnEntryInEveryCasing() {
    Self.expectReadings([
      ("I love Sci-Fi movies.", "ˌI lˈʌv sˈIfˌI mˈuviz.", "ˌI lˈʌv sˈIfI mˈuːviz."),
      ("I love sci-fi movies.", "ˌI lˈʌv sˈIfˌI mˈuviz.", "ˌI lˈʌv sˈIfI mˈuːviz."),
      ("Sci-fi is back.", "sˈIfˌI ɪz bˈæk.", "sˈIfI ɪz bˈak."),
      ("SCI-FI IS BACK.", "sˈIfˌI ˈɪz bˈæk.", "sˈIfI ˈɪz bˈak.")
    ])
  }

  /// The same fault in the compounds beside it. Before, American "wi-fi" was
  /// `wˈifˈi` ("wee-fee"), British "Wi-Fi" `wˈiːfˈiː`, and "THE WI-FI"
  /// `ðə dˌʌbᵊljuˈIˌɛfˈI`; "hi-fi" and "lo-fi" read `hˈIfˈi` and `lˈOfˈi`
  /// here, and reached gold only where the tagger called the hyphen a noun.
  @Test func theOtherFiCompoundsReadFromTheirEntries() {
    Self.expectReadings([
      ("The Wi-Fi is down.", "ðə wˈIfˌI ɪz dˌWn.", "ðə wˈIfˌI ɪz dˌWn."),
      ("The wi-fi is down.", "ðə wˈIfˌI ɪz dˌWn.", "ðə wˈIfˌI ɪz dˌWn."),
      ("Wi-fi is down.", "wˈIfˌI ɪz dˌWn.", "wˈIfˌI ɪz dˌWn."),
      ("THE WI-FI IS DOWN.", "ðə wˈIfˌI ˈɪz dˈWn.", "ðə wˈIfˌI ˈɪz dˈWn."),
      ("A hi-fi system.", "ɐ hˈIfˌI sˈɪstəm.", "ɐ hˈIfI sˈɪstɪm."),
      ("A lo-fi mix.", "ɐ lˈOfˌI mˈɪks.", "ɐ lˈQfI mˈɪks.")
    ])
  }

  /// The rule reads the hyphen's text, not its tag. spaCy calls most
  /// intra-word hyphens HYPH but these two `:`, which is punctuation here, so
  /// a rule under the dash tag alone left them standing apart: "Hi-Fi is
  /// back." stayed `hˈIfˈI` / `hˈIfˈiː`, and "TICK-TOCK" read "tick" and then
  /// spelled T-O-C-K (`tˈɪktˌiˌOsˌikˈA`).
  @Test func aHyphenTheTaggerCallsPunctuationIsStillInsideItsCompound() {
    Self.expectReadings([
      ("Hi-Fi is back.", "hˈIfˌI ɪz bˈæk.", "hˈIfI ɪz bˈak."),
      ("I like TICK-TOCK today.", "ˌI lˈIk tˈɪktˌɑk tədˈA.", "ˌI lˈIk tˈɪktɒk tədˈA.")
    ])
  }

  /// A compound of three parts: the run is walked both ways from each hyphen
  /// and cut longest first. Before: `kˈOˈInˈʊɹ` / `kˈQˈInˈʊə`, `bɹˈɪkɐbɹˈæk` /
  /// `bɹˈɪkɐbɹˈak` and `tˈɪktˈæktˈO` / `tˈɪktˈaktˈQ`. British gold lists
  /// "tic-tac" as well, so its column is the one that fails shortest-first.
  @Test func aCompoundOfThreePartsIsReadWhole() {
    Self.expectReadings([
      ("The Koh-i-noor diamond.", "ðə kˌOinˈʊɹ dˈIəmənd.", "ðə kˈQɪnˌʊə dˈIəmənd."),
      ("A bric-a-brac shop.", "ɐ bɹˈɪkəbɹˌæk ʃˈɑp.", "ɐ bɹˈɪkəbɹak ʃˈɒp."),
      ("A game of tic-tac-toe.", "ɐ ɡˈAm ʌv tˌɪktˌæktˈO.", "ɐ ɡˈAm ɒv tɪktaktˈQ.")
    ])
  }

  /// A run of more words than gold's longest compound is not searched, so
  /// the walk is bounded: seven words find "sci-fi" at their end, eight read
  /// as they did before.
  @Test func aRunLongerThanAnyCompoundIsNotSearched() {
    Self.expectReadings([
      ("two-three-four-five-six-sci-fi stuff.",
       "tˈuθɹˈifˈɔɹfˈIvsˈɪkssˈIfˌI stˈʌf.", "tˈuːθɹˈiːfˈɔːfˈIvsˈɪkssˈIfI stˈʌf."),
      ("one-two-three-four-five-six-sci-fi stuff.",
       "wˈʌntˈuθɹˈifˈɔɹfˈIvsˈɪkssˈIfˈi stˈʌf.", "wˈʌntˈuːθɹˈiːfˈɔːfˈIvsˈɪkssˈIfˈiː stˈʌf.")
    ])
  }

  /// A clitic, and a hyphen that joins the compound to something else, are
  /// outside it: the hyphen after "Sci-Fi" in "Sci-Fi-inspired" still
  /// separates. "Non-sci-fi" was `nɑnsˈifˈi`, one group read whole by the
  /// fallback, because the tagger leaves its first hyphen in the group; the
  /// compound in it is now found, and "Non-" reads from gold's prefix entry.
  @Test func theCompoundKeepsItsNeighbours() {
    Self.expectReadings([
      ("Sci-Fi's golden age.", "sˈIfˌIz ɡˈOldən ˈAʤ.", "sˈIfIz ɡˈQldᵊn ˈAʤ."),
      ("A Sci-Fi-inspired design.", "ɐ sˈIfˌIɪnspˈIəɹd dəzˈIn.", "ɐ sˈIfIɪnspˈIəd dɪzˈIn."),
      ("Non-sci-fi shows.", "nˌɑnsˈIfˌI ʃˈOz.", "nˌɒnsˈIfI ʃˈQz.")
    ])
  }

  /// What must not move. A compound whose parts all read keeps the
  /// part-by-part reading, whether gold lists it ("long-term" `lˈɔŋtˌɜɹm`,
  /// "forty-five" `fˌɔɹɾifˈIv`) or not, so a listed number does not come to
  /// differ from the unlisted one beside it. A forced span is not a part.
  @Test func aCompoundWhosePartsAllReadIsLeftAlone() {
    Self.expectReadings([
      ("A long-term plan.", "ɐ lˈɔŋtˈɜɹm plˈæn.", "ɐ lˈɒŋtˈɜːm plˈan."),
      ("He is forty-five.", "hˌi ɪz fˈɔɹTifˈIv.", "hˌiː ɪz fˈɔːtifˈIv."),
      ("It runs on-device.", "ˌɪt ɹˈʌnz ˌɔndəvˈIs.", "ˌɪt ɹˈʌnz ˌɒndɪvˈIs."),
      ("A state-of-the-art lab.", "ɐ stˈAtʌvðiˈɑɹt lˈæb.", "ɐ stˈAtɒvðiˈɑːt lˈab."),
      ("A [Sci](/sˈI/)-fi film.", "ɐ sˈIfˈi fˈɪlm.", "ɐ sˈIfˈiː fˈɪlm.")
    ])
  }

  /// The two questions `joinsListedCompound` asks of the lexicon.
  @Test func theLexiconSaysWhichCompoundsItListsAndWhichPartsItReads() {
    for lexicon in [Lexicon(british: false), Lexicon(british: true)] {
      for listed in ["sci-fi", "Sci-Fi", "Sci-fi", "SCI-FI", "Wi-Fi", "wi-fi", "Wi-fi", "long-term"] {
        #expect(lexicon.listsCompound(listed), "\(listed) should be listed")
      }
      // "RE-" folds to gold's prefix `re-`, which carries no primary stress.
      for unlisted in ["on-device", "sci-Fi", "ABC-DEF", "RE-"] {
        #expect(!lexicon.listsCompound(unlisted), "\(unlisted) should not be listed")
      }
      for read in ["long", "term", "Long", "hi", "T", "NASA"] {
        #expect(lexicon.reads(read), "\(read) should read")
      }
      // An unlisted run of capitals is spelled, which is not a reading.
      for unread in ["sci", "Sci", "SCI", "fi", "Fi", "wi"] {
        #expect(!lexicon.reads(unread), "\(unread) should not read")
      }
    }
  }

  /// Gold entries that drop a part of the compound they key. Before, British
  /// "The post-bellum South." was `ðə bˈɛləm sˈWθ.` and "A sub-boreal
  /// climate." `ɐ bˈɔːɹɪəl klˈImɪt.`
  @Test func aTruncatedEntryIsNotRead() {
    Self.expectReadings([
      ("The post-bellum South.", "ðə pˌOstbˈɛləm sˈWθ.", "ðə pˌQstbˈɛləm sˈWθ."),
      ("A sub-boreal climate.", "ɐ sˌʌbbˈɔɹiəl klˈImət.", "ɐ sˌʌbbˈɔːɹɪəl klˈImɪt."),
      ("We bought a washer-dryer.", "wˌi bˈɔt ɐ wˈɔʃəɹdɹˈIəɹ.", "wˌiː bˈɔːt ɐ wˈɒʃədɹˈIə."),
      ("In Schleswig-Holstein today.", "ɪn ʃlˈɛzwɪɡhˈOlstˌIn tədˈA.", "ɪn ʃlˈɛsvɪɡhˈɒlstIn tədˈA.")
    ])
  }

  /// No casing of a withdrawn entry is listed, in either lexicon it was
  /// withdrawn from. The readings above cannot show this for an entry whose
  /// parts all read, which was never read whole in those sentences.
  @Test func aWithdrawnEntryIsUnlistedInEveryCasing() {
    for british in [false, true] {
      let lexicon = Lexicon(british: british)
      for key in Lexicon.truncatedCompoundGolds(british: british) {
        let lower = key.lowercased()
        let casings = [key, lower, lower.capitalized, lower.prefix(1).uppercased() + lower.dropFirst(), key.uppercased()]
        for casing in casings {
          #expect(!lexicon.listsCompound(casing), "\(casing) is still listed")
        }
      }
    }
  }

  /// Each withdrawn entry is still in the resource and still short, so a
  /// lexicon that repairs one fails here and the entry can come back.
  @Test func everyWithdrawnEntryIsStillTruncatedInTheResource() {
    let british = DataResourcesUtil.loadGold(british: true)
    let expectedBritish = [
      "Benue-Congo": "bˈɛnwA", "Hubli-Dharwar": "dɑːwˈɑː",
      "Pretoria-Witwatersrand-Vereeniging": "fəɹˈiːnɪkɪŋ", "Schleswig-Holstein": "hˈɒlstIn",
      "Sub-Boreal": "bˈɔːɹɪəl", "concavo-concave": "kɒnkˈAvQ", "muckety-muck": "mˈʌkəmʌk",
      "post-bellum": "bˈɛləm", "post-chaises": "pˈQsʧAz"
    ]
    #expect(Set(expectedBritish.keys) == Lexicon.truncatedCompoundGolds(british: true))
    for (key, reading) in expectedBritish {
      #expect(british[key] as? String == reading, "\(key) changed in gb_gold")
    }

    let american = DataResourcesUtil.loadGold(british: false)
    #expect(Lexicon.truncatedCompoundGolds(british: false) == ["washer-dryer"])
    #expect(american["washer-dryer"] as? String == "wˈɔʃəɹ")
  }
}
