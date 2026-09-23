import Testing
@testable import MisakiSwift

/// The `-ed` ending agrees in voicing with the sound before it: /t/ after a
/// voiceless consonant ("raced" /ɹˈAst/), /d/ after a voiced obstruent.
/// `pastEd` has always applied that rule to a form it derives from a stem, but
/// a form the lexicon lists outright is read verbatim and never reaches
/// `stem_ed`.
///
/// 46 listed forms broke the rule -- 45 with /d/ after /p f s ʃ/, one with /t/
/// after /z/ -- across all four tiers: us_gold 2, us_silver 20, gb_gold 2,
/// gb_silver 22. A silver hit outranks the stem, so "raced" read `ɹˈAsd` in
/// both dialects while "placed", "faced" and "traced" beside it, whose listed
/// values were right, read `-st`. Each value was corrected in place by its
/// final phoneme alone; nothing else in the data files moved.
struct PastTenseVoicingTests {

  /// The invariant, over the raw data rather than the grown dictionaries, so
  /// that a future re-sync of the lexicon files cannot bring the class back
  /// silently. Gold is swept as `Lexicon.init` builds it, with the
  /// hand-written `supplementalGolds` merged in. "-eed" keys are skipped only
  /// to mirror `stem_ed`'s own guard: their final /d/ is the stem's
  /// ("speed", "bleed"), and none of them could match either pattern anyway.
  /// A vowel or sonorant before /t/ is not checked: the only such `-ed` entry
  /// today is German "volkslied" (/t/ from "Lied"), and a British `-t` past
  /// ("learnt", "spelt") listed under `-ed` would be a legitimate reading.
  @Test func noListedPastTenseDisagreesInVoicingWithItsStem() {
    let voicelessThenD = /[pkfθsʃʧ]d$/
    let voicedObstruentThenT = /[bɡvðzʒʤ]t$/
    let tiers: [(name: String, entries: [String: Any])] = [
      ("us_gold", Self.gold(british: false)),
      ("us_silver", DataResourcesUtil.loadSilver(british: false)),
      ("gb_gold", Self.gold(british: true)),
      ("gb_silver", DataResourcesUtil.loadSilver(british: true))
    ]

    for tier in tiers {
      #expect(!tier.entries.isEmpty, "\(tier.name) failed to load")
      for (word, value) in tier.entries {
        let spelling = word.lowercased()
        guard spelling.hasSuffix("ed"), !spelling.hasSuffix("eed") else { continue }
        let readings: [String]
        if let heteronyms = value as? [String: Any] {
          readings = heteronyms.values.compactMap { $0 as? String }
        } else {
          readings = [value as? String].compactMap { $0 }
        }
        for reading in readings {
          #expect(reading.firstMatch(of: voicelessThenD) == nil,
                  "\(tier.name) \(word.debugDescription) voices its ending: \(reading)")
          #expect(reading.firstMatch(of: voicedObstruentThenT) == nil,
                  "\(tier.name) \(word.debugDescription) devoices its ending: \(reading)")
        }
      }
    }
  }

  /// The reported word, in each casing the grown dictionary serves and in a
  /// sentence. Measured before: `ɹˈAsd` in both dialects, from the silver tier.
  @Test func racedEndsInAVoicelessT() throws {
    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      #expect(g2p.phonemize(text: "raced").0 == "ɹˈAst", "british=\(british)")
      #expect(g2p.phonemize(text: "Raced").0 == "ɹˈAst", "british=\(british)")
      #expect(g2p.phonemize(text: "She raced home.").0.contains(" ɹˈAst "), "british=\(british)")
    }
  }

  /// One form from each tier that carried the fault, measured before as the
  /// value the tier listed. The silver ones are the common words: "typed",
  /// "nursed" and "scoped" are in both dialects' silver files.
  @Test func eachTiersFormsTakeTheVoicingTheirStemDictates() throws {
    let fixtures: [(british: Bool, word: String, expected: String)] = [
      (false, "typed", "tˈIpt"),        // us_silver, was tˈIpd
      (false, "nursed", "nˈɜɹst"),      // us_silver, was nˈɜɹsd
      (false, "leafed", "lˈift"),       // us_gold, was lˈifd
      (true, "scoped", "skˈQpt"),       // gb_silver, was skˈQpd
      (true, "walloped", "wˈɒləpt"),    // gb_silver, was wˈɒləpd
      (true, "unburnished", "ʌnbˈɜːnɪʃt"), // gb_gold, was ʌnbˈɜːnɪʃd
      (true, "premised", "pɹɪmˈIzd")    // gb_gold, was pɹɪmˈIzt
    ]

    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      for fixture in fixtures where fixture.british == british {
        #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
                "wrong reading for \(fixture.word.debugDescription), british=\(british)")
      }
    }
  }

  /// Siblings of "raced" that were already right stay exactly where they were:
  /// listed forms from gold ("faced") and silver ("placed", "traced",
  /// "chased", "braced"), and two that no tier lists, derived by `stem_ed`
  /// from a gold stem -- the path whose voicing was never at fault.
  @Test func theSiblingsThatAlreadyReadCorrectlyDoNotMove() throws {
    let listed: [(word: String, expected: String)] = [
      ("placed", "plˈAst"),
      ("faced", "fˈAst"),
      ("traced", "tɹˈAst"),
      ("chased", "ʧˈAst"),
      ("braced", "bɹˈAst")
    ]
    let derived: [(british: Bool, word: String, expected: String)] = [
      (false, "endorsed", "ɪndˈɔɹst"),
      (false, "enhanced", "ɪnhˈænst"),
      (true, "endorsed", "ɪndˈɔːst"),
      (true, "enhanced", "ɪnhˈɑːnst")
    ]

    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      let fixtures = listed + derived.filter { $0.british == british }.map { ($0.word, $0.expected) }
      for fixture in fixtures {
        #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
                "wrong reading for \(fixture.word.debugDescription), british=\(british)")
      }
    }
  }

  private static func gold(british: Bool) -> [String: Any] {
    DataResourcesUtil.loadGold(british: british)
      .merging(Lexicon.supplementalGolds(british: british)) { _, supplement in supplement }
  }
}
