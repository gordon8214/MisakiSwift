import Testing
@testable import MisakiSwift

/// Two words are one space apart, and a mark stands against the word before
/// it, whatever was erased or emptied between them.
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
/// were" gave its /z/ 25 ms and 500 ms. Every "before" in the first three
/// tests was measured at `86f7f55`, and in the last four at `146f857`.
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

  /// A token with no reading takes no space of its own. Erased between two
  /// spaces it used to leave both: each row here had a pair where the comment
  /// marks it, and "15s`" had one for a second reason, a group's own space
  /// and the backtick's. Rendered on the bundled CoreML chain over 40 such
  /// lines, the word's last phoneme and the gap took 166 ms with the pair
  /// and 105 ms without, and the audio held 45 ms of silence there against 22.
  ///
  /// The dash spelled in hyphens is in this list on purpose. The pair was the
  /// only break it had (over 40 lines, 108 ms of silence with it and 30 ms
  /// without), and it is not kept, because it was never the dash's reading:
  /// the same pair stood beside every brace. A caller spells the dash "—".
  /// The signed figure is erased whole, a fault of its own that the pair hid
  /// no better.
  @Test func aTokenWithNoReadingLeavesOneSpace() {
    Self.expectReadings([
      // `ðə  slˈæʃ ʧˈʌŋk  flˈæɡ`.
      ("Run the ` slash chunk ` flag first.",
       "ɹˈʌn ðə slˈæʃ ʧˈʌŋk flˈæɡ fˈɜɹst.", "ɹˈʌn ðə slˈaʃ ʧˈʌŋk flˈaɡ fˈɜːst."),
      // `ɪn  bɹˈAsᵻz  hˈɪɹ`.
      ("Wrap it in { braces } here.", "ɹˈæp ɪt ɪn bɹˈAsᵻz hˈɪɹ.", "ɹˈap ɪt ɪn bɹˈAsɪz hˈɪə."),
      // `sˈi  ðə nˈOt  bəlˈO`.
      ("See [ the note ] below.", "sˈi ðə nˈOt bəlˈO.", "sˈiː ðə nˈQt bɪlˈQ."),
      // `kˈɔsts  fˈIv`: the sign is erased and its figure reads the currency.
      ("It costs $ 5 today.", "ˌɪt kˈɔsts fˈIv dˈɑləɹz tədˈA.", "ˌɪt kˈɒsts fˈIv dˈɒləz tədˈA."),
      // `fˌɪftˈinz  tə`.
      ("It took 15s` to run.", "ˌɪt tˈʊk fˌɪftˈinz tə ɹˈʌn.", "ˌɪt tˈʊk fˌɪftˈiːnz tə ɹˈʌn."),
      // `mˈɑɹkət  wˌɪʧ fˈɛl  ɹˈOz`.
      ("The market -- which fell -- rose.", "ðə mˈɑɹkət wˌɪʧ fˈɛl ɹˈOz.", "ðə mˈɑːkɪt wˌɪʧ fˈɛl ɹˈQz."),
      // `mˈuvd  tədˈA`.
      ("It moved -3 today.", "ˌɪt mˈuvd tədˈA.", "ˌɪt mˈuːvd tədˈA.")
    ])
  }

  /// A group stands against the mark after it, as any word does. Its space
  /// is the separator an emptied subtoken leaves, and before a mark it stood
  /// in front of the mark: `nˈIndiz , ɪt`, `nˈIndiz .`, `nˈIndiz )`,
  /// `nˈIndiz "` and `nˈIndiz —ænd`, a shape upstream never emits. A brace
  /// erased between the two is looked past. A forced reading that ends in a
  /// space closes up the same way. Over 30 rendered lines the mark kept its
  /// pause: the last phoneme and the gap took 425 ms with the space and 438
  /// without.
  @Test func aGroupStandsAgainstTheMarkAfterIt() {
    Self.expectReadings([
      ("In the 1990s, it was popular.",
       "ɪn ðə nˌIntˈin nˈIndiz, ɪt wʌz pˈɑpjələɹ.", "ɪn ðə nˌIntˈiːn nˈIntiz, ɪt wɒz pˈɒpjʊlə."),
      ("It was popular in the 1990s.",
       "ˌɪt wʌz pˈɑpjələɹ ɪn ðə nˌIntˈin nˈIndiz.", "ˌɪt wɒz pˈɒpjʊlə ɪn ðə nˌIntˈiːn nˈIntiz."),
      ("The decade (the 1990s) was long.",
       "ðə dˈɛkˌAd (ðə nˌIntˈin nˈIndiz) wʌz lˈɔŋ.", "ðə dˈɛkAd (ðə nˌIntˈiːn nˈIntiz) wɒz lˈɒŋ."),
      ("He called it \"the 1990s\" again.",
       "hˌi kˈɔld ɪt \"ðə nˌIntˈin nˈIndiz\" əɡˈɛn.", "hˌiː kˈɔːld ɪt \"ðə nˌIntˈiːn nˈIntiz\" əɡˈɛn."),
      ("He called it “the 1990s” again.",
       "hˌi kˈɔld ɪt “ðə nˌIntˈin nˈIndiz” əɡˈɛn.", "hˌiː kˈɔːld ɪt “ðə nˌIntˈiːn nˈIntiz” əɡˈɛn."),
      ("In the 1990s—and after—it grew.",
       "ɪn ðə nˌIntˈin nˈIndiz—ænd ˈæftəɹ—ɪt ɡɹˈu.", "ɪn ðə nˌIntˈiːn nˈIntiz—and ˈɑːftə—ɪt ɡɹˈuː."),
      ("It grew {in the 1990s}, then fell.",
       "ˌɪt ɡɹˈu ɪn ðə nˌIntˈin nˈIndiz, ðˈɛn fˈɛl.", "ˌɪt ɡɹˈuː ɪn ðə nˌIntˈiːn nˈIntiz, ðˈɛn fˈɛl."),
      ("A [word](/wˈɜɹd /), next.", "ɐ wˈɜɹd, nˈɛkst.", "ɐ wˈɜɹd, nˈɛkst.")
    ])
  }

  /// A mark glued to the group from the other side, which "word(roughly)",
  /// `word"roughly"` and "word:next" read with no space either: `wˈɜɹd(ɹˈʌfli)`,
  /// `wˈɜɹd:nˈɛkst`. The group read `nˈIndiz (ɹˈʌfli)` and `fˌɪftˈinz :nˈɛkst`.
  @Test func aGroupStandsAgainstAGluedMarkAsAWordDoes() {
    Self.expectReadings([
      ("The 1990s(roughly) were long.",
       "ðə nˌIntˈin nˈIndiz(ɹˈʌfli) wɜɹ lˈɔŋ.", "ðə nˌIntˈiːn nˈIntiz(ɹˈʌfli) wɜː lˈɒŋ."),
      ("The 1990s“roughly” were long.",
       "ðə nˌIntˈin nˈIndiz“ɹˈʌfli” wɜɹ lˈɔŋ.", "ðə nˌIntˈiːn nˈIntiz“ɹˈʌfli” wɜː lˈɒŋ."),
      ("It took 15s:next and more.",
       "ˌɪt tˈʊk fˌɪftˈinz:nˈɛkst ænd mˈɔɹ.", "ˌɪt tˈʊk fˌɪftˈiːnz:nˈɛkst and mˈɔː.")
    ])
  }

  /// Where that space is still the separator, and where a space was typed.
  /// A word after an erased bracket has no whitespace before it, so the
  /// group's space is all that keeps the two apart. A space the writer put
  /// in front of a mark is the writer's, after a group as after any word.
  @Test func theSpaceBeforeAWordOrATypedSpaceIsKept() {
    Self.expectReadings([
      ("In the 1990s[note] it grew.",
       "ɪn ðə nˌIntˈin nˈIndiz nˈOt ɪt ɡɹˈu.", "ɪn ðə nˌIntˈiːn nˈIntiz nˈQt ɪt ɡɹˈuː."),
      ("The 1990s , it seems.", "ðə nˌIntˈin nˈIndiz , ɪt sˈimz.", "ðə nˌIntˈiːn nˈIntiz , ɪt sˈiːmz."),
      ("A word , then more.", "ɐ wˈɜɹd , ðˈɛn mˈɔɹ.", "ɐ wˈɜːd , ðˈɛn mˈɔː.")
    ])
  }
}
