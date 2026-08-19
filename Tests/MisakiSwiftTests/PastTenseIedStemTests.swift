import Testing
@testable import MisakiSwift

/// `stem_ed` reaching a `-y` verb's past tense, the counterpart of the `-ies`
/// branch `stem_s` has always had.
///
/// Without it neither of the earlier branches can produce a stem for a `-ied`
/// form -- "copied" offers only "copie" and "copi", and neither is a word -- so
/// the whole form fell through to the BART fallback. That network reads a
/// SPELLING, and it answered the "cope" vowel. Most `-ied` spellings it happens
/// to guess right, which is why the gap survived; the ones it does not are
/// where a silent-e cousin is what the letters most resemble.
struct PastTenseIedStemTests {

  /// The reported word, in both dialects. "copy" is in each lexicon and "cope"
  /// / "coped" are too, which is exactly what the spelling reader reached for.
  @Test func copiedKeepsTheCopyVowelRatherThanTheCopeOne() {
    #expect(EnglishG2P(british: false).phonemize(text: "copied").0 == "kˈɑpid")
    #expect(EnglishG2P(british: true).phonemize(text: "copied").0 == "kˈɒpid")
  }

  /// The stem is resolved through the lexicon, so the reading is the one the
  /// base verb already has -- including where the fallback dropped a syllable
  /// outright ("unbusied" was `ʌnbˈɪzd`) or reached for the wrong vowel
  /// ("lilied" was `lˈIlid`, "wearied" the "wear" vowel).
  @Test func aKnownYStemDecidesItsOwnPastTense() {
    let fixtures: [(word: String, british: Bool, expected: String)] = [
      ("lilied", false, "lˈɪlid"),
      ("palsied", false, "pˈɔlzid"),
      ("alimonied", false, "ˈæləmˌOnid"),
      ("wearied", true, "wˈɪəɹid"),
      ("unbusied", true, "ʌnbˈɪzid"),
      ("queried", true, "kwˈɪəɹid")
    ]

    for fixture in fixtures {
      let g2p = EnglishG2P(british: fixture.british)
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription)")
    }
  }

  /// The two bounds, both mirroring `stem_s`. A word that merely ends in "ied"
  /// without being a `-y` past tense has no known stem to find, and the
  /// `count > 4` floor keeps the one-syllable set out -- dropping three
  /// characters from "died" leaves "dy", and from "tied" leaves "ty".
  @Test func aWordWithNoKnownYStemIsLeftAlone() {
    let g2p = EnglishG2P(british: false)
    #expect(g2p.phonemize(text: "died").0 == "dˈId")
    #expect(g2p.phonemize(text: "tied").0 == "tˈId")
    #expect(g2p.phonemize(text: "lied").0 == "lˈId")
    #expect(g2p.phonemize(text: "vied").0 == "vˈId")
  }

  /// The branch is last, so a form an earlier one already resolves is
  /// untouched: "belied" stops at the known stem "belie", and the ordinary
  /// `-ied` verbs the fallback was already reading correctly do not move.
  @Test func theCommonPastTensesAreUnchanged() {
    let fixtures: [(word: String, expected: String)] = [
      ("studied", "stˈʌdid"),
      ("carried", "kˈɛɹid"),
      ("married", "mˈɛɹid"),
      ("tried", "tɹˈId"),
      ("applied", "əplˈId"),
      ("occupied", "ˈɑkjəpˌId"),
      ("emptied", "ˈɛmptid")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription)")
    }
  }
}
