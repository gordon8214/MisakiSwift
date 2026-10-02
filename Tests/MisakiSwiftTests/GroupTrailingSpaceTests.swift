import Testing
@testable import MisakiSwift

/// A group whose last subtoken was emptied is followed by one space, not two.
///
/// "1st" is two subtokens, "1" and "st". The group is read whole ("first"),
/// which empties "st", and `mergeTokens` puts a space before every subtoken
/// that has a reading, an empty one included. The group's reading therefore
/// ends in a space, and the final join added the token's own whitespace after
/// it. Kokoro's vocabulary has the space as a token, so that was two tokens,
/// and the model reads the pair as a phrase break.
///
/// Rendered on the bundled CoreML chain over 60 prose lines, one space against
/// two: the word's last phoneme and the gap took 120 ms and 222 ms on average,
/// and 3 lines held 200 ms or more of silence there against 14. "the 1950s
/// were" gave its /z/ 25 ms and 500 ms. Every "before" below was measured at
/// `86f7f55`.
struct GroupTrailingSpaceTests {

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

  /// The shapes prose has: an ordinal, a figure with a plural or possessive
  /// "s", a decade, and a word with a trailing slash. Before, each had two
  /// spaces where the comment marks them: `fˈɜɹst  tˈu`, `tˈɛnz  ʧˈʌŋks`,
  /// `nˈIndiz  wɜɹ`, `fˈɔɹTiz  wɜɹ`, `θɹˈiz  ˈWtpˌʊt`, `hˈʌndɹədθ  ˌænəvˈɜɹsəɹi`
  /// and `slˈæʃ  dəɹˈɛktəɹi`. The figure after "1st" reads as three words,
  /// which is what tells a reading that ends in a space from one that only
  /// holds one.
  @Test func aGroupThatEndsOnAnEmptiedSubtokenTakesOneSpace() {
    Self.expectReadings([
      ("The 1st 290 pages are free.",
       "ðə fˈɜɹst tˈu hˈʌndɹəd nˈIndi pˈAʤᵻz ɑɹ fɹˈi.",
       "ðə fˈɜːst tˈuː hˈʌndɹəd nˈInti pˈAʤɪz ɑː fɹˈiː."),
      ("We split it into 10s chunks.",
       "wˌi splˈɪt ɪt ˈɪntu tˈɛnz ʧˈʌŋks.", "wˌiː splˈɪt ɪt ˈɪntuː tˈɛnz ʧˈʌŋks."),
      ("The 1990s were a long decade.",
       "ðə nˌIntˈin nˈIndiz wɜɹ ɐ lˈɔŋ dˈɛkˌAd.", "ðə nˌIntˈiːn nˈIntiz wɜː ɐ lˈɒŋ dˈɛkAd."),
      ("The '40s were hard.", "ðə fˈɔɹTiz wɜɹ hˈɑɹd.", "ðə fˈɔːtiz wɜː hˈɑːd."),
      ("Version v3's output was best.",
       "vˈɜɹʒən vˈi θɹˈiz ˈWtpˌʊt wʌz bˈɛst.", "vˈɜːʃᵊn vˈiː θɹˈiːz ˈWtpʊt wɒz bˈɛst."),
      ("The 100th anniversary.",
       "ðə wˈʌn hˈʌndɹədθ ˌænəvˈɜɹsəɹi.", "ðə wˈʌn hˈʌndɹədθ ˌanɪvˈɜːsəɹi."),
      ("Open the slash/ directory first.",
       "ˈOpᵊn ðə slˈæʃ dəɹˈɛktəɹi fˈɜɹst.", "ˈQpᵊn ðə slˈaʃ dɪɹˈɛktəɹi fˈɜːst.")
    ])
  }

  /// Why the space is dropped at the join and not in `mergeTokens`, where
  /// upstream drops it. With no whitespace after the group, the same space
  /// is all that separates it from what follows: upstream's rule read
  /// "5th-order" as `fˈɪfθˈɔɹdəɹ` and "2nd-largest" as `sˈɛkəndlˈɑɹʤᵻst`.
  @Test func theSpaceThatSeparatesAGroupFromAHyphenatedWordIsKept() {
    Self.expectReadings([
      ("The 5th-order filter is stable.",
       "ðə fˈɪfθ ˈɔɹdəɹ fˈɪltəɹ ɪz stˈAbᵊl.", "ðə fˈɪfθ ˈɔːdə fˈɪltə ɪz stˈAbᵊl."),
      ("It is the 2nd-largest city.",
       "ˌɪt ɪz ðə sˈɛkənd lˈɑɹʤᵻst sˈɪTi.", "ˌɪt ɪz ðə sˈɛkᵊnd lˈɑːʤɪst sˈɪti.")
    ])
  }

  /// A forced reading is the other way a reading comes to end in a space,
  /// and it takes one too (it had two). It is the space that is tested for
  /// and not whitespace: a forced reading that ends in a tab keeps the space
  /// after it, because the vocabulary has no tab, the tokenizer drops it, and
  /// the two words would be left with nothing between them.
  @Test func aForcedReadingKeepsItsSeparatorWhateverItEndsIn() {
    Self.expectReadings([
      ("A [word](/wˈɜɹd /) next.", "ɐ wˈɜɹd nˈɛkst.", "ɐ wˈɜɹd nˈɛkst."),
      ("A [word](/wˈɜɹd\t/) next.", "ɐ wˈɜɹd\t nˈɛkst.", "ɐ wˈɜɹd\t nˈɛkst."),
      ("A [word](/wˈɜɹd\u{A0}/) next.", "ɐ wˈɜɹd\u{A0} nˈɛkst.", "ɐ wˈɜɹd\u{A0} nˈɛkst.")
    ])
  }

  /// Three neighbours of this fault that are not it, pinned as they are so
  /// the rule stays as narrow as it was measured.
  ///
  /// A token erased between two spaces leaves both of them. For a spaced
  /// dash, which has no reading, those two spaces are the only break it gets,
  /// so collapsing them would run the clauses together.
  ///
  /// With punctuation after the group, its space stands in front of the
  /// mark. That lengthens or shortens a pause the writer asked for (a comma's
  /// by 57 ms of 375 over 18 renders, a full stop's by 28 ms of 465 the other
  /// way over 22) and adds none.
  ///
  /// A group followed at once by a token that is erased takes that token's
  /// whitespace after its own space, so it still has two.
  @Test func anErasedTokenAndASpaceBeforePunctuationAreLeftAlone() {
    Self.expectReadings([
      ("It took 15s` to run.", "ˌɪt tˈʊk fˌɪftˈinz  tə ɹˈʌn.", "ˌɪt tˈʊk fˌɪftˈiːnz  tə ɹˈʌn."),
      ("The market -- which fell -- rose.",
       "ðə mˈɑɹkət  wˌɪʧ fˈɛl  ɹˈOz.", "ðə mˈɑːkɪt  wˌɪʧ fˈɛl  ɹˈQz."),
      ("It moved -3 today.", "ˌɪt mˈuvd  tədˈA.", "ˌɪt mˈuːvd  tədˈA."),
      ("In the 1990s, it was popular.",
       "ɪn ðə nˌIntˈin nˈIndiz , ɪt wʌz pˈɑpjələɹ.", "ɪn ðə nˌIntˈiːn nˈIntiz , ɪt wɒz pˈɒpjʊlə."),
      ("It was popular in the 1990s.",
       "ˌɪt wʌz pˈɑpjələɹ ɪn ðə nˌIntˈin nˈIndiz .", "ˌɪt wɒz pˈɒpjʊlə ɪn ðə nˌIntˈiːn nˈIntiz .")
    ])
  }
}
