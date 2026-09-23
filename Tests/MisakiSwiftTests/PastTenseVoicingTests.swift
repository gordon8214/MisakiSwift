import Testing
@testable import MisakiSwift

/// The `-ed` ending agrees in voicing with the sound before it: /t/ after a
/// voiceless consonant ("raced" /ɹˈAst/), /d/ after a voiced one. `pastEd`
/// has always applied that rule to a form it derives from a stem, but a form
/// the lexicon lists outright is read verbatim and never reaches `stem_ed`.
///
/// 46 listed forms broke the rule -- 45 with /d/ after /p k f s ʃ/, one with
/// /t/ after /z/ -- across all four tiers: us_gold 2, us_silver 20, gb_gold 2,
/// gb_silver 22. A silver hit outranks the stem, so "raced" read `ɹˈAsd` in
/// both dialects while "placed", "faced" and "traced" beside it were right.
/// Each value was corrected in place by its final phoneme alone; nothing else
/// in the data files moved.
struct PastTenseVoicingTests {

  /// The invariant, over the raw data rather than the grown dictionaries, so
  /// that a future re-sync of the lexicon files cannot bring the class back
  /// silently. "-eed" keys are skipped because their final /d/ is the stem's
  /// own ("speed", "bleed"), not the suffix.
  @Test func noListedPastTenseDisagreesInVoicingWithItsStem() {
    let voicelessThenD = /[pkfθsʃʧ]d$/
    let voicedThenT = /[bɡvðzʒʤ]t$/
    let tiers: [(name: String, entries: [String: Any])] = [
      ("us_gold", DataResourcesUtil.loadGold(british: false)),
      ("us_silver", DataResourcesUtil.loadSilver(british: false)),
      ("gb_gold", DataResourcesUtil.loadGold(british: true)),
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
          #expect(reading.firstMatch(of: voicedThenT) == nil,
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
    let fixtures: [(word: String, british: Bool, expected: String)] = [
      ("typed", false, "tˈIpt"),       // us_silver, was tˈIpd
      ("nursed", false, "nˈɜɹst"),     // us_silver, was nˈɜɹsd
      ("leafed", false, "lˈift"),      // us_gold, was lˈifd
      ("scoped", true, "skˈQpt"),      // gb_silver, was skˈQpd
      ("walloped", true, "wˈɒləpt"),   // gb_silver, was wˈɒləpd
      ("unburnished", true, "ʌnbˈɜːnɪʃt"), // gb_gold, was ʌnbˈɜːnɪʃd
      ("premised", true, "pɹɪmˈIzd")   // gb_gold, was pɹɪmˈIzt
    ]

    for fixture in fixtures {
      let g2p = try EnglishG2P(british: fixture.british, requireRemoteFrontendParity: true)
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription), british=\(fixture.british)")
    }
  }

  /// Siblings of "raced" that were already right, from gold, silver and
  /// `stem_ed` alike, stay exactly where they were.
  @Test func theSiblingsThatAlreadyReadCorrectlyDoNotMove() throws {
    let fixtures: [(word: String, expected: String)] = [
      ("placed", "plˈAst"),
      ("faced", "fˈAst"),
      ("traced", "tɹˈAst"),
      ("chased", "ʧˈAst"),
      ("braced", "bɹˈAst")
    ]

    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      for fixture in fixtures {
        #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
                "wrong reading for \(fixture.word.debugDescription), british=\(british)")
      }
    }
  }
}
