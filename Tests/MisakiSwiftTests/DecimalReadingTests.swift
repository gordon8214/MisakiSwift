import Foundation
import Testing
@testable import MisakiSwift

/// A decimal is read from its digits, not from its value.
///
/// `Lexicon.getNumber` used to hand a decimal to `EnglishNum2Word` as
/// `Decimal(Double(text))`. That conversion is inexact for 15,340 of the
/// 100,000 two-digit fractions under a thousand (and for none of the one-digit
/// ones, which is why "2.9" always read correctly), so the reader was given
/// 6.769999999999998976 for "6.77" and spoke every digit of it. Where the
/// mantissa that made reaches 2^63, as it does for 2,972 of them,
/// `NSDecimalNumber.intValue` is wrong as well, so the whole part changed too.
///
/// Nothing about the fault needs a suffix: a bare "6.77" took the same branch.
/// It was reported on "6.77s" because BetterFeeds spells a bare decimal itself
/// and leaves one that is glued to letters, or that ends a sentence, to this
/// frontend. Every "before" below was measured at `ecdf2aa`.
struct DecimalReadingTests {

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

  /// The reported readings. "6.77s" was `sˈɪks pYnt sˈɛvən sˈɪks nˈIn` (twelve
  /// times) `ˈAt nˈIn sˈɛvən sˈɪksᵻz`, and "8.81s" `ˈAt pYnt ˈAt wˈʌn zˈɪɹO`
  /// (twelve times) `tˈu zˈɪɹO fˈɔɹ ˈAts`. The plural is the suffix rule's and
  /// is unchanged: it now lands on the last digit that was written.
  @Test func aFractionIsTheDigitsThatWereWritten() {
    Self.expectReadings([
      ("It took 6.77s to run.",
       "ˌɪt tˈʊk sˈɪks pYnt sˈɛvən sˈɛvənz tə ɹˈʌn.", "ˌɪt tˈʊk sˈɪks pYnt sˈɛvᵊn sˈɛvᵊnz tə ɹˈʌn."),
      ("It took 8.81s to run.",
       "ˌɪt tˈʊk ˈAt pYnt ˈAt wˈʌnz tə ɹˈʌn.", "ˌɪt tˈʊk ˈAt pYnt ˈAt wˈʌnz tə ɹˈʌn."),
      ("It grew 14.96%.",
       "ˌɪt ɡɹˈu fˌɔɹtˈin pYnt nˈIn sˈɪks pəɹsˈɛnt.", "ˌɪt ɡɹˈuː fˌɔːtˈiːn pYnt nˈIn sˈɪks pəsˈɛnt.")
    ])
  }

  /// The whole part was misread too. "14.96" was "minus three point zero nine
  /// six zero…", "1.06" opened on "zero", and "1,234.56" was "minus six
  /// hundred ten point four four zero five five nine…".
  @Test func theWholePartIsTheOneThatWasWritten() {
    Self.expectReadings([
      ("The score was 14.96.",
       "ðə skˈɔɹ wʌz fˌɔɹtˈin pYnt nˈIn sˈɪks.", "ðə skˈɔː wɒz fˌɔːtˈiːn pYnt nˈIn sˈɪks."),
      ("It weighs 1.06 kilograms.",
       "ˌɪt wˈAz wˈʌn pYnt zˈɪɹO sˈɪks kˈɪləɡɹˌæmz.", "ˌɪt wˈAz wˈʌn pYnt zˈɪəɹQ sˈɪks kˈɪləɡɹamz."),
      ("It cost 1,234.56 in all.",
       "ˌɪt kˈɔst wˈʌn θˈWzᵊnd tˈu hˈʌndɹəd θˈɜɹTi fˈɔɹ pYnt fˈIv sˈɪks ˈɪn ˈɔl.",
       "ˌɪt kˈɒst wˈʌn θˈWzᵊnd tˈuː hˈʌndɹəd θˈɜːti fˈɔː pYnt fˈIv sˈɪks ˈɪn ˈɔːl.")
    ])
  }

  /// A zero that was written is read. By value "2.50" was "two point five",
  /// "3.10" was "three point one", which is another version, and "2.0" was
  /// "two". Upstream misaki reads through a float and drops it as well; this
  /// is a deliberate divergence. BetterFeeds spells the decimals it reaches
  /// with every digit, so one figure read "two point five zero" inside a
  /// sentence and "two point five" at the end of one.
  @Test func aWrittenZeroIsRead() {
    Self.expectReadings([
      ("It rose to 2.50 today.",
       "ˌɪt ɹˈOz tə tˈu pYnt fˈIv zˈɪɹO tədˈA.", "ˌɪt ɹˈQz tə tˈuː pYnt fˈIv zˈɪəɹQ tədˈA."),
      ("Version 3.10 shipped.",
       "vˈɜɹʒən θɹˈi pYnt wˈʌn zˈɪɹO ʃˈɪpt.", "vˈɜːʃᵊn θɹˈiː pYnt wˈʌn zˈɪəɹQ ʃˈɪpt."),
      ("Python 2.0 is old.",
       "pˈIθˌɑn tˈu pYnt zˈɪɹO ɪz ˈOld.", "pˈIθn tˈuː pYnt zˈɪəɹQ ɪz ˈQld.")
    ])
  }

  /// A fraction longer than a `Double` holds is read digit for digit: the
  /// tail of this one was "three seven nine two", what `Decimal(Double)` made
  /// of it. A price in whole cents has a branch of its own and never took
  /// this one.
  @Test func aLongFractionAndAPriceAreReadAsWritten() {
    Self.expectReadings([
      ("Pi is 3.14159265358979323846 or so.",
       "pˈI ɪz θɹˈi pYnt wˈʌn fˈɔɹ wˈʌn fˈIv nˈIn tˈu sˈɪks fˈIv θɹˈi fˈIv ˈAt nˈIn sˈɛvən nˈIn θɹˈi tˈu θɹˈi ˈAt fˈɔɹ sˈɪks ɔɹ sˌO.",
       "pˈI ɪz θɹˈiː pYnt wˈʌn fˈɔː wˈʌn fˈIv nˈIn tˈuː sˈɪks fˈIv θɹˈiː fˈIv ˈAt nˈIn sˈɛvᵊn nˈIn θɹˈiː tˈuː θɹˈiː ˈAt fˈɔː sˈɪks ɔː sˌQ."),
      ("It cost $14.96 today.",
       "ˌɪt kˈɔst fˌɔɹtˈin dˈɑləɹz ænd nˈIndi sˈɪks sˈɛnts tədˈA.",
       "ˌɪt kˈɒst fˌɔːtˈiːn dˈɒləz and nˈInti sˈɪks sˈɛnts tədˈA.")
    ])
  }

  /// Every two-digit fraction under a thousand, which is where the inexact
  /// conversion bit: the whole part's own cardinal, "point", and the two
  /// digits.
  @Test func everyTwoDigitFractionReadsAsItsDigits() {
    let reader = EnglishNum2Word()
    let digitNames = (0...9).map { reader.convert(Decimal($0)) }
    var misread: [String] = []
    for whole in 0..<1000 {
      let wholeWords = reader.convert(Decimal(whole))
      for fraction in 0..<100 {
        let text = "\(whole).\(fraction / 10)\(fraction % 10)"
        let expected = "\(wholeWords) point \(digitNames[fraction / 10]) \(digitNames[fraction % 10])"
        if reader.convert(decimalText: text) != expected { misread.append(text) }
      }
    }
    #expect(misread.isEmpty, "\(misread.count) misread, the first \(misread.prefix(5))")
  }

  /// What the reader takes: digits around at most one point. A sign is the
  /// caller's to say, because "-0.5" has no negative whole part to carry it;
  /// a whole part past `Int` is left unread, as an integer that long is.
  @Test func onlyDigitsAroundOnePointAreRead() {
    let reader = EnglishNum2Word()
    #expect(reader.convert(decimalText: "6.77") == "six point seven seven")
    #expect(reader.convert(decimalText: "6.770") == "six point seven seven zero")
    #expect(reader.convert(decimalText: "0.05") == "zero point zero five")
    #expect(reader.convert(decimalText: "25") == "twenty-five")
    #expect(reader.convert(decimalText: "5.") == "five")
    #expect(reader.convert(decimalText: "007.5") == "seven point five")
    #expect(reader.convert(decimalText: "00.5") == "zero point five")

    for refused in ["", ".5", "-0.5", "+5.5", "5.5.5", "1.5e3", "5.٥", "٥.5", "5,5", "99999999999999999999.5"] {
      #expect(reader.convert(decimalText: refused) == nil, "read \(refused.debugDescription)")
    }
  }

  /// A fraction is read to its twenty-fourth digit and no further. Read by
  /// value it stopped at eighteen or so, and BetterFeeds leaves a fraction
  /// longer than twenty-four in digits so that nothing expands it: with no
  /// bound here, a hundred thousand digits after "3." are a hundred thousand
  /// words. The whole fraction of the first row is read, and the second and
  /// third stop where it does.
  @Test func aFractionIsReadToItsTwentyFourthDigit() {
    let reader = EnglishNum2Word()
    let twentyFour = "one four one five nine two six five three five eight nine seven nine three two three eight four six two six four three"
    #expect(EnglishNum2Word.maximumFractionDigits == 24)
    #expect(reader.convert(decimalText: "3.141592653589793238462643") == "three point " + twentyFour)
    #expect(reader.convert(decimalText: "3.1415926535897932384626433") == "three point " + twentyFour)
    #expect(reader.convert(decimalText: "3.1415926535897932384626433" + String(repeating: "8", count: 5_000))
            == "three point " + twentyFour)

    Self.expectReadings([
      ("Pi is 3.14159265358979323846264338327950288419716939937510 or so.",
       "pˈI ɪz θɹˈi pYnt wˈʌn fˈɔɹ wˈʌn fˈIv nˈIn tˈu sˈɪks fˈIv θɹˈi fˈIv ˈAt nˈIn sˈɛvən nˈIn θɹˈi tˈu θɹˈi ˈAt fˈɔɹ sˈɪks tˈu sˈɪks fˈɔɹ θɹˈi ɔɹ sˌO.",
       "pˈI ɪz θɹˈiː pYnt wˈʌn fˈɔː wˈʌn fˈIv nˈIn tˈuː sˈɪks fˈIv θɹˈiː fˈIv ˈAt nˈIn sˈɛvᵊn nˈIn θɹˈiː tˈuː θɹˈiː ˈAt fˈɔː sˈɪks tˈuː sˈɪks fˈɔː θɹˈiː ɔː sˌQ.")
    ])
  }

  /// A whole part past `Int` has no reading, as an integer that long has
  /// none, and nothing is made up for it. By value this one was the digits of
  /// another number, "seven thousand seven hundred sixty six thousand…", with
  /// a "point" after them.
  @Test func aWholePartPastIntIsLeftUnread() {
    for british in [false, true] {
      let reading = EnglishG2P(british: british).phonemize(text: "It measured 99999999999999999999.5 units.").0
      #expect(!reading.contains("pYnt"), "read by value: \(reading)")
      #expect(reading.hasPrefix("ˌɪt mˈɛʒə") && reading.contains("jˈu"), "lost its neighbours: \(reading)")
    }
  }

  /// A `Decimal` goes through the same reader. Taken apart by value, a
  /// mantissa of 2^63 or more lost its whole part (this one opened on
  /// "zero"), and a negative fraction read its own point as a digit: -2.5 was
  /// "minus two point zero five" and -0.5 "zero point zero five".
  @Test func aDecimalValueIsReadFromItsDigitsToo() throws {
    let reader = EnglishNum2Word()
    let fixtures: [(String, String)] = [
      ("3.14159265358979323846",
       "three point one four one five nine two six five three five eight nine seven nine three two three eight four six"),
      ("-2.5", "minus two point five"),
      ("-0.5", "minus zero point five"),
      ("14.96", "fourteen point nine six"),
      ("25", "twenty-five"),
      ("-5", "minus five")
    ]
    for (text, expected) in fixtures {
      let number = try #require(Decimal(string: text))
      #expect(reader.convert(number) == expected, "wrong reading for \(text)")
    }
  }

  /// A value whose whole part is past `Int` has no reading either. It used
  /// to be whatever `NSDecimalNumber.intValue` answered: the digits of
  /// another number for twenty zeros, and for sixty-three `Int.min`, on which
  /// the cardinal traps. One part of a dotted run reaches it, so that text
  /// stopped the process; the part is now passed over.
  @Test func aValuePastIntIsPassedOverAndDoesNotTrap() throws {
    let reader = EnglishNum2Word()
    for zeros in [20, 63] {
      let text = "1" + String(repeating: "0", count: zeros)
      #expect(reader.convert(try #require(Decimal(string: text))) == "", "\(zeros) zeros")
      Self.expectReadings([
        ("Build 1.2.\(text) shipped.", "bˈɪld wˈʌn tˈu ʃˈɪpt.", "bˈɪld wˈʌn tˈuː ʃˈɪpt.")
      ])
    }
  }
}
