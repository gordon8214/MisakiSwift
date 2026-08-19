import Testing
@testable import MisakiSwift

/// `stem_ing` preferring the silent-e stem over the bare one.
///
/// The order only decides anything when BOTH candidates are known words, and
/// there the bare stem was the wrong guess: English doubles a stressed final
/// consonant before `-ing`, so a form spelled `Xing` whose `Xe` is a verb is
/// that verb -- "automating" is "automate", not the vending-machine restaurant
/// "automat", which would be spelled "automatting".
///
/// Measured over every `-ing` word in `/usr/share/dict/words` (5,491 entries)
/// plus "automating": exactly three readings move, and all three are repairs.
struct ProgressiveIngStemTests {

  /// The reported word. "automat" is a gold entry in both lexicons, so the
  /// bare-stem branch resolved and "automating" read "auto-MATT-ing".
  @Test func automatingTakesTheAutomateStemRatherThanAutomat() {
    #expect(EnglishG2P(british: false).phonemize(text: "automating").0 == "ˈɔTəmˌATɪŋ")
    #expect(EnglishG2P(british: true).phonemize(text: "automating").0 == "ˈɔːtəmAtɪŋ")
  }

  /// The other two words the reorder moves, both found by sweeping the
  /// dictionary rather than reported. "cur" is the mongrel dog; "synthesis"
  /// is the noun the British spelling of the verb is built on.
  @Test func theOtherBothStemsKnownFormsAreRepairedToo() {
    let fixtures: [(word: String, british: Bool, expected: String)] = [
      ("curing", false, "kjˈʊɹɪŋ"),
      ("curing", true, "kjˈʊəɹɪŋ"),
      ("synthesising", false, "sˈɪnθəsˌIzɪŋ"),
      ("synthesising", true, "sˈɪnθɪsIzɪŋ")
    ]

    for fixture in fixtures {
      let g2p = EnglishG2P(british: fixture.british)
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription)")
    }
  }

  /// The bare-stem branch is still reached whenever no `-e` counterpart
  /// exists, which is the whole unstressed-final class. These are the forms a
  /// naive "always add the e" rule would have broken.
  @Test func anUnstressedFinalSyllableStillKeepsItsBareStem() {
    let fixtures: [(word: String, expected: String)] = [
      ("benefiting", "bˈɛnɪfˌɪTɪŋ"),
      ("targeting", "tˈɑɹɡəTɪŋ"),
      ("budgeting", "bˈʌʤəTɪŋ"),
      ("pivoting", "pˈɪvəTɪŋ"),
      ("orbiting", "ˈɔɹbəTɪŋ")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription)")
    }
  }

  /// The doubled-consonant branch is still last, and the common `-ing` forms
  /// that resolve straight out of the lexicon never reach the stemmer at all.
  /// "singing" is the one pair where the bare stem is the right answer and a
  /// silent-e cousin exists ("singe"); it is a direct lexicon hit, which is
  /// why the reorder cannot reach it.
  @Test func theCommonProgressivesAreUnchanged() {
    let fixtures: [(word: String, expected: String)] = [
      ("singing", "sˈɪŋɪŋ"),
      ("running", "ɹˈʌnɪŋ"),
      ("hopping", "hˈɑpɪŋ"),
      ("hoping", "hˈOpɪŋ"),
      ("bathing", "bˈAðɪŋ"),
      ("clothing", "klˈOðɪŋ"),
      ("writing", "ɹˈITɪŋ"),
      ("stating", "stˈATɪŋ")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      #expect(g2p.phonemize(text: fixture.word).0 == fixture.expected,
              "wrong reading for \(fixture.word.debugDescription)")
    }
  }
}
