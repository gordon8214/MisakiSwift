import Testing
@testable import MisakiSwift

/// A decimal is read as one wherever it stands in its token.
///
/// A subtoken group reads its head and the rest differently. `getNumber` sent
/// every figure that was not the head of its group to the branch that reads a
/// dotted run ("1.2.3"), which takes the parts between the dots as numbers of
/// their own and says no "point". A sign, a joining hyphen or a letter in
/// front of a decimal makes it such a figure, so "+0.12" was "plus zero
/// twelve" and "GPT-4.5" "GPT four five". Over 45 values after "+", "model-"
/// and "GPT-", at the end of a sentence and inside one, 270 of 270 readings
/// had lost the point. Upstream misaki has the same branch
/// (`word.count('.') > 1 or not is_head`); reading the point there is a
/// deliberate divergence. Every "before" below was measured at `b795727`.
struct GluedDecimalTests {

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

  /// The reported readings, in a sentence and at the end of one. "+0.12" was
  /// `plˈʌs zˈɪɹO twˈɛlv`, "+6.77" "plus six seventy seven", "+2.50" "plus two
  /// fifty", "GPT-4.5" `ʤˌipˌitˈi fˈɔɹ fˈIv` and "model-0.12" "model zero
  /// twelve". The written zero of "+2.50" is read, as the head's is.
  @Test func aDecimalAfterASignOrAJoiningHyphenKeepsItsPoint() {
    Self.expectReadings([
      ("It gained +0.12 today.",
       "ˌɪt ɡˈAnd plˈʌs zˈɪɹO pYnt wˈʌn tˈu tədˈA.", "ˌɪt ɡˈAnd plˈʌs zˈɪəɹQ pYnt wˈʌn tˈuː tədˈA."),
      ("It gained +6.77.",
       "ˌɪt ɡˈAnd plˈʌs sˈɪks pYnt sˈɛvən sˈɛvən.", "ˌɪt ɡˈAnd plˈʌs sˈɪks pYnt sˈɛvᵊn sˈɛvᵊn."),
      ("It gained +2.50 today.",
       "ˌɪt ɡˈAnd plˈʌs tˈu pYnt fˈIv zˈɪɹO tədˈA.", "ˌɪt ɡˈAnd plˈʌs tˈuː pYnt fˈIv zˈɪəɹQ tədˈA."),
      ("They shipped GPT-4.5 today.",
       "ðˌA ʃˈɪpt ʤˌipˌitˈi fˈɔɹ pYnt fˈIv tədˈA.", "ðˌA ʃˈɪpt ʤˌiːpˌiːtˈiː fˈɔː pYnt fˈIv tədˈA."),
      ("They shipped model-0.12 today.",
       "ðˌA ʃˈɪpt mˈɑdᵊl zˈɪɹO pYnt wˈʌn tˈu tədˈA.", "ðˌA ʃˈɪpt mˈɒdᵊl zˈɪəɹQ pYnt wˈʌn tˈuː tədˈA.")
    ])
  }

  /// What BetterFeeds still hands over in digits: a decimal with letters
  /// glued behind it and the mantissa of an exponent, which its normalizer
  /// leaves alone. They were "plus six seventy seven ex" and "plus one zero
  /// six e zero four". A plural lands on the last digit written, as the
  /// head's does ("plus zero twelves" before).
  @Test func aGluedMultiplierAndAnExponentKeepTheirPoint() {
    Self.expectReadings([
      ("It grew +6.77x.",
       "ˌɪt ɡɹˈu plˈʌs sˈɪks pYnt sˈɛvən sˈɛvən ˈɛks.", "ˌɪt ɡɹˈuː plˈʌs sˈɪks pYnt sˈɛvᵊn sˈɛvᵊn ˈɛks."),
      ("The loss was +1.06e-04 today.",
       "ðə lˈɔs wʌz plˈʌs wˈʌn pYnt zˈɪɹO sˈɪks ˈi zˈɪɹO fˈɔɹ tədˈA.",
       "ðə lˈɒs wɒz plˈʌs wˈʌn pYnt zˈɪəɹQ sˈɪks ˈiː zˈɪəɹQ fˈɔː tədˈA."),
      ("It took +0.12s today.",
       "ˌɪt tˈʊk plˈʌs zˈɪɹO pYnt wˈʌn tˈuz tədˈA.", "ˌɪt tˈʊk plˈʌs zˈɪəɹQ pYnt wˈʌn tˈuːz tədˈA.")
    ])
  }

  /// A letter in front makes the figure the same non-head: "v10.25" was "v
  /// ten twenty five", "USB3.2" "three two" and "python3.11" "three eleven".
  /// The last is the one reading the dotted run had a case for, and it is
  /// "three point one one" with a space in front of it in any caller that
  /// spells decimals, as BetterFeeds does.
  @Test func aDecimalGluedToLettersKeepsItsPoint() {
    Self.expectReadings([
      ("They shipped v10.25 today.",
       "ðˌA ʃˈɪpt vˈi tˈɛn pYnt tˈu fˈIv tədˈA.", "ðˌA ʃˈɪpt vˈiː tˈɛn pYnt tˈuː fˈIv tədˈA."),
      ("It uses USB3.2 today.",
       "ˌɪt jˈuzᵻz jˌuˌɛsbˈi θɹˈi pYnt tˈu tədˈA.", "ˌɪt jˈuːzɪz jˌuːˌɛsbˈiː θɹˈiː pYnt tˈuː tədˈA."),
      ("Run python3.11 today.",
       "ɹˈʌn pˈIθˌɑn θɹˈi pYnt wˈʌn wˈʌn tədˈA.", "ɹˈʌn pˈIθn θɹˈiː pYnt wˈʌn wˈʌn tədˈA.")
    ])
  }

  /// A grouped whole part is a cardinal, where it was read digit by digit
  /// ("plus one two three four fifty six"); a fraction of three digits is
  /// read to its last ("plus zero one two five" before); and the second
  /// figure of a pair has its point too ("one point five two five").
  @Test func aGroupedWholePartALongerFractionAndASecondFigureAreReadAsDecimals() {
    Self.expectReadings([
      ("It cost +1,234.56 today.",
       "ˌɪt kˈɔst plˈʌs wˈʌn θˈWzᵊnd tˈu hˈʌndɹəd θˈɜɹTi fˈɔɹ pYnt fˈIv sˈɪks tədˈA.",
       "ˌɪt kˈɒst plˈʌs wˈʌn θˈWzᵊnd tˈuː hˈʌndɹəd θˈɜːti fˈɔː pYnt fˈIv sˈɪks tədˈA."),
      ("It gained +0.125 today.",
       "ˌɪt ɡˈAnd plˈʌs zˈɪɹO pYnt wˈʌn tˈu fˈIv tədˈA.", "ˌɪt ɡˈAnd plˈʌs zˈɪəɹQ pYnt wˈʌn tˈuː fˈIv tədˈA."),
      ("The ratio was 1.5/2.5 today.",
       "ðə ɹˈAʃiO wʌz wˈʌn pYnt fˈIv tˈu pYnt fˈIv tədˈA.", "ðə ɹˈAʃɪQ wɒz wˈʌn pYnt fˈIv tˈuː pYnt fˈIv tədˈA.")
    ])
  }

  /// Every comma of a grouped whole part is dropped, as the head's are. Only
  /// the point is asserted: the whole part is seven digits, and the cardinal
  /// reads a million through "thousand" twice, for a head as well.
  @Test func aWholePartGroupedTwiceIsStillADecimal() {
    for british in [false, true] {
      let reading = EnglishG2P(british: british).phonemize(text: "It cost +1,234,567.5 today.").0
      #expect(reading.contains("pYnt fˈIv tədˈA."), "no point: \(reading)")
    }
  }

  /// What is still a dotted run, each read as it was. A point with no digit
  /// in front closes an abbreviation after a letter ("H.264"), and after a
  /// sign that leaves "+.5" as "plus five". Two points are a version. A whole
  /// part past `Int` has no reading as a decimal, and sent on as one it would
  /// take its group to the fallback; this one is read digit by digit.
  @Test func aDottedRunIsStillReadByItsParts() {
    let nines = Array(repeating: "nˈIn", count: 20).joined(separator: " ")
    Self.expectReadings([
      ("They use H.264 video.", "ðˌA jˈuz ˈAʧ tˈu sˈɪks fˈɔɹ vˈɪdiO.", "ðˌA jˈuːz ˈAʧ tˈuː sˈɪks fˈɔː vˈɪdɪQ."),
      ("It moved +.5 today.", "ˌɪt mˈuvd plˈʌs fˈIv tədˈA.", "ˌɪt mˈuːvd plˈʌs fˈIv tədˈA."),
      ("Build +1.2.3 shipped.", "bˈɪld plˈʌs wˈʌn tˈu θɹˈi ʃˈɪpt.", "bˈɪld plˈʌs wˈʌn tˈuː θɹˈiː ʃˈɪpt."),
      ("It moved +99999999999999999999.5 today.",
       "ˌɪt mˈuvd plˈʌs \(nines) fˈIv tədˈA.", "ˌɪt mˈuːvd plˈʌs \(nines) fˈIv tədˈA.")
    ])
  }

  /// A whole part written with a zero in front of it is a code, and it keeps
  /// that zero: a diagnosis code, an episode number, a padded figure. Read as
  /// decimals these were "E eight point nine", "S one point five" and "plus
  /// seven point five", each another code.
  @Test func aZeroPaddedWholePartIsStillReadByItsDigits() {
    Self.expectReadings([
      ("The claim was coded E08.9 and J06.9.",
       "ðə klˈAm wʌz kˈOdᵻd ˈi zˈɪɹO ˈAt nˈIn ænd ʤˈA zˈɪɹO sˈɪks nˈIn.",
       "ðə klˈAm wɒz kˈQdɪd ˈiː zˈɪəɹQ ˈAt nˈIn and ʤˈA zˈɪəɹQ sˈɪks nˈIn."),
      ("The episode is S01.5 here.",
       "ði ˈɛpəsˌOd ɪz ˈɛs zˈɪɹO wˈʌn fˈIv hˈɪɹ.", "ði ˈɛpɪsQd ɪz ˈɛs zˈɪəɹQ wˈʌn fˈIv hˈɪə."),
      ("It moved +007.5 today.",
       "ˌɪt mˈuvd plˈʌs zˈɪɹO zˈɪɹO sˈɛvən fˈIv tədˈA.", "ˌɪt mˈuːvd plˈʌs zˈɪəɹQ zˈɪəɹQ sˈɛvᵊn fˈIv tədˈA."),
      // Zeros alone are padding too.
      ("It moved +00.5 today.",
       "ˌɪt mˈuvd plˈʌs zˈɪɹO zˈɪɹO fˈIv tədˈA.", "ˌɪt mˈuːvd plˈʌs zˈɪəɹQ zˈɪəɹQ fˈIv tədˈA.")
    ])
  }

  /// A figure that carries a currency and is not the head of its group is a
  /// decimal and not an amount. The currency branch was only ever the
  /// head's: a whole number that is not a head is read with no currency
  /// ("$US105" is "one oh five"), so a decimal there is too. Before, these
  /// were "one zero five five", "zero five" and "three twenty".
  @Test func aDecimalAfterACurrencyCodeIsNotReadAsCents() {
    Self.expectReadings([
      ("Iron ore fetched $US105.5 a tonne.",
       "ˈIəɹn ˈɔɹ fˈɛʧt ˈʌs wˈʌn hˈʌndɹəd fˈIv pYnt fˈIv ɐ tˈʌn.",
       "ˈIən ˈɔː fˈɛʧt ˈʌs wˈʌn hˈʌndɹəd fˈIv pYnt fˈIv ɐ tˈʌn."),
      ("The fare is $NZ0.5 a ride.",
       "ðə fˈɛɹ ɪz ˌɛnzˈi zˈɪɹO pYnt fˈIv ɐ ɹˈId.", "ðə fˈɛː ɪz ˌɛnzˈiː zˈɪəɹQ pYnt fˈIv ɐ ɹˈId."),
      ("The fare is $NZ3.20 a ride.",
       "ðə fˈɛɹ ɪz ˌɛnzˈi θɹˈi pYnt tˈu zˈɪɹO ɐ ɹˈId.", "ðə fˈɛː ɪz ˌɛnzˈiː θɹˈiː pYnt tˈuː zˈɪəɹQ ɐ ɹˈId.")
    ])
  }
}
