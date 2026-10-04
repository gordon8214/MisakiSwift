import Testing
@testable import MisakiSwift

/// A million is said "million".
///
/// `EnglishNum2Word.toCardinal` tried the thousands before the millions, and
/// every number of 1,000 or more is a count of thousands, so the loop that
/// names a million, a billion and a trillion was never reached: 5,000,000
/// read "five thousand thousand" and 1,234,567 "one thousand two hundred
/// thirty four thousand five hundred sixty seven". The port's own; the
/// Python `num2words` it was made from reads the largest power first. Every
/// "before" below was measured at `113ff75`.
struct CardinalMillionTests {

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

  /// `fˈIv θˈWzᵊnd θˈWzᵊnd`, `wˈʌn θˈWzᵊnd tˈu hˈʌndɹəd θˈɜɹTi fˈɔɹ
  /// θˈWzᵊnd…` and `wˈʌn θˈWzᵊnd wˈʌn θˈWzᵊnd` before.
  @Test func aMillionIsNamed() {
    Self.expectReadings([
      ("It holds 5000000 rows.", "ˌɪt hˈOldz fˈIv mˈɪljᵊn ɹˈOz.", "ˌɪt hˈQldz fˈIv mˈɪljən ɹˈQz."),
      ("It holds 1234567 rows.",
       "ˌɪt hˈOldz wˈʌn mˈɪljᵊn tˈu hˈʌndɹəd θˈɜɹTi fˈɔɹ θˈWzᵊnd fˈIv hˈʌndɹəd sˈɪksti sˈɛvən ɹˈOz.",
       "ˌɪt hˈQldz wˈʌn mˈɪljən tˈuː hˈʌndɹəd θˈɜːti fˈɔː θˈWzᵊnd fˈIv hˈʌndɹəd sˈɪksti sˈɛvᵊn ɹˈQz."),
      ("It holds 1001000 rows.",
       "ˌɪt hˈOldz wˈʌn mˈɪljᵊn wˈʌn θˈWzᵊnd ɹˈOz.", "ˌɪt hˈQldz wˈʌn mˈɪljən wˈʌn θˈWzᵊnd ɹˈQz.")
    ])
  }

  /// The largest power is named first, and what is left under it after: a
  /// billion's remainder is millions. `tˈu θˈWzᵊnd fˈIv hˈʌndɹəd θˈWzᵊnd
  /// θˈWzᵊnd` before.
  @Test func aBillionAndATrillionAreNamedLargestFirst() {
    Self.expectReadings([
      ("It holds 2500000000 rows.",
       "ˌɪt hˈOldz tˈu bˈɪljən fˈIv hˈʌndɹəd mˈɪljᵊn ɹˈOz.", "ˌɪt hˈQldz tˈuː bˈɪljən fˈIv hˈʌndɹəd mˈɪljən ɹˈQz."),
      ("It holds 1000000000000 rows.", "ˌɪt hˈOldz wˈʌn tɹˈɪljən ɹˈOz.", "ˌɪt hˈQldz wˈʌn tɹˈɪljən ɹˈQz."),
      // The last two powers an `Int` holds.
      ("It holds 1000000000000000 rows.", "ˌɪt hˈOldz wˈʌn kwɑdɹˈɪljən ɹˈOz.", "ˌɪt hˈQldz wˈʌn kwɒdɹˈɪljən ɹˈQz."),
      ("It holds 1000000000000000000 rows.", "ˌɪt hˈOldz wˈʌn kwɪntˈɪljən ɹˈOz.", "ˌɪt hˈQldz wˈʌn kwɪntˈɪljən ɹˈQz.")
    ])
  }

  /// Under a million the thousands read as they did.
  @Test func theThousandsAreUnchanged() {
    Self.expectReadings([
      ("It holds 999999 rows.",
       "ˌɪt hˈOldz nˈIn hˈʌndɹəd nˈIndi nˈIn θˈWzᵊnd nˈIn hˈʌndɹəd nˈIndi nˈIn ɹˈOz.",
       "ˌɪt hˈQldz nˈIn hˈʌndɹəd nˈInti nˈIn θˈWzᵊnd nˈIn hˈʌndɹəd nˈInti nˈIn ɹˈQz.")
    ])
  }

  /// Every reader of a cardinal has it: an ordinal ("one thousand
  /// thousandth" before) and the whole part of a decimal. Gold lists the
  /// ordinals up to "trillionth"; the two powers above it get theirs from
  /// the cardinal's reading, or they would be spelled letter by letter.
  @Test func anOrdinalAndADecimalsWholePartNameTheMillion() {
    Self.expectReadings([
      ("It was the 1000000th row.", "ˌɪt wʌz ðə wˈʌn mˈɪljənθ ɹˈO.", "ˌɪt wɒz ðə wˈʌn mˈɪljənθ ɹˈQ."),
      ("It was the 1000000000000000th row.",
       "ˌɪt wʌz ðə wˈʌn kwɑdɹˈɪljənθ ɹˈO.", "ˌɪt wɒz ðə wˈʌn kwɒdɹˈɪljənθ ɹˈQ."),
      ("It was the 1000000000000000000th row.",
       "ˌɪt wʌz ðə wˈʌn kwɪntˈɪljənθ ɹˈO.", "ˌɪt wɒz ðə wˈʌn kwɪntˈɪljənθ ɹˈQ."),
      ("It cost +1,234,567.5 today.",
       "ˌɪt kˈɔst plˈʌs wˈʌn mˈɪljᵊn tˈu hˈʌndɹəd θˈɜɹTi fˈɔɹ θˈWzᵊnd fˈIv hˈʌndɹəd sˈɪksti sˈɛvən pYnt fˈIv tədˈA.",
       "ˌɪt kˈɒst plˈʌs wˈʌn mˈɪljən tˈuː hˈʌndɹəd θˈɜːti fˈɔː θˈWzᵊnd fˈIv hˈʌndɹəd sˈɪksti sˈɛvᵊn pYnt fˈIv tədˈA.")
    ])
  }
}
