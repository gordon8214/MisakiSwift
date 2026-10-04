import MLXUtilsLibrary
import Testing
@testable import MisakiSwift

/// The fraction of an amount is cents, and an amount is one figure.
///
/// `Lexicon.getNumber` reads a figure that carries a currency as a count of
/// the unit and a count of its hundredth. Two amounts were read as other
/// amounts. One with no whole part ("$.50") was split at its point with the
/// empty part dropped, so the fraction was taken for the whole: "fifty
/// dollars". Upstream's `split('.')` keeps the empty part; that one was the
/// port's. And one digit of a fraction was that many cents: "$1.5" was "one
/// dollar and five cents", as it is upstream.
///
/// And `EnglishG2P.retokenize` gave the currency to every figure it met
/// until a token that is no number came by. A mark is not looked at there,
/// so the figure across one from an amount was an amount too, as it is
/// upstream. Every "before" below was measured at `113ff75`.
struct CurrencyFractionTests {

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

  /// "$.50" was `fˈɪfti dˈɑləɹz`, "$.99" "ninety nine dollars" and "$.5"
  /// "five dollars".
  @Test func anAmountWithNoWholePartIsCents() {
    Self.expectReadings([
      ("It cost $.50 today.", "ˌɪt kˈɔst fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst fˈɪfti sˈɛnts tədˈA."),
      ("It cost $.99 today.", "ˌɪt kˈɔst nˈIndi nˈIn sˈɛnts tədˈA.", "ˌɪt kˈɒst nˈInti nˈIn sˈɛnts tədˈA."),
      ("It cost $.5 today.", "ˌɪt kˈɔst fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst fˈɪfti sˈɛnts tədˈA.")
    ])
  }

  /// "$1.5" was `wˈʌn dˈɑləɹ ænd fˈIv sˈɛnts`, "$0.5" "five cents" and
  /// "£2.5" "two pounds and five pence".
  @Test func oneDigitOfAFractionIsTenths() {
    Self.expectReadings([
      ("It cost $1.5 today.",
       "ˌɪt kˈɔst wˈʌn dˈɑləɹ ænd fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst wˈʌn dˈɒlə and fˈɪfti sˈɛnts tədˈA."),
      ("It cost $0.5 today.", "ˌɪt kˈɔst fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst fˈɪfti sˈɛnts tədˈA."),
      ("It cost £2.5 today.",
       "ˌɪt kˈɔst tˈu pˈWndz ænd fˈɪfti pˈɛns tədˈA.", "ˌɪt kˈɒst tˈuː pˈWndz and fˈɪfti pˈɛns tədˈA.")
    ])
  }

  /// Two digits are hundredths, as they were, a zero in front included, and
  /// zeros alone add nothing.
  @Test func twoDigitsAreHundredthsAndZerosAreNone() {
    Self.expectReadings([
      ("It cost $1.50 today.",
       "ˌɪt kˈɔst wˈʌn dˈɑləɹ ænd fˈɪfti sˈɛnts tədˈA.", "ˌɪt kˈɒst wˈʌn dˈɒlə and fˈɪfti sˈɛnts tədˈA."),
      ("It cost $1.05 today.",
       "ˌɪt kˈɔst wˈʌn dˈɑləɹ ænd fˈIv sˈɛnts tədˈA.", "ˌɪt kˈɒst wˈʌn dˈɒlə and fˈIv sˈɛnts tədˈA."),
      ("It cost $1.000 today.", "ˌɪt kˈɔst wˈʌn dˈɑləɹ tədˈA.", "ˌɪt kˈɒst wˈʌn dˈɒlə tədˈA.")
    ])
  }

  /// The currency is given to one figure. "(2.3%)" after an amount was "two
  /// dollars and three cents percent". It still travels to the last number
  /// of a run, which is how "$1.5 billion" has its dollars after "billion",
  /// and the run goes on across a hyphen that joins a figure to a scale,
  /// "hundred" to "trillion": spaCy cuts "$5-million" at the hyphen, and it
  /// read "five dollars million dollars" ("one dollar and five cents billion
  /// dollars" for "$1.5-billion", "two dollars trillion dollars"), whether
  /// the tagger calls that hyphen a hyphen or a symbol ("$300-million",
  /// where it read "three hundred dollars million", and "$5-hundred", "five
  /// dollars hundred"). A hyphen before a figure is a range's, read as it
  /// was, and one before any other number word joins a compound ("five
  /// dollars one dollars way" for "$5-one-way").
  @Test func theFigureAfterAnAmountIsNotAnAmount() {
    Self.expectReadings([
      ("It rose $120.50 (2.3%) today.",
       "ˌɪt ɹˈOz wˈʌn hˈʌndɹəd twˈɛnti dˈɑləɹz ænd fˈɪfti sˈɛnts (tˈu pYnt θɹˈi pəɹsˈɛnt) tədˈA.",
       "ˌɪt ɹˈQz wˈʌn hˈʌndɹəd twˈɛnti dˈɒləz and fˈɪfti sˈɛnts (tˈuː pYnt θɹˈiː pəsˈɛnt) tədˈA."),
      ("It cost $1.5 billion today.",
       "ˌɪt kˈɔst wˈʌn pYnt fˈIv bˈɪljən dˈɑləɹz tədˈA.", "ˌɪt kˈɒst wˈʌn pYnt fˈIv bˈɪljən dˈɒləz tədˈA."),
      ("It was a $5-million deal.",
       "ˌɪt wʌz ɐ fˈIvmˈɪljᵊn dˈɑləɹz dˈil.", "ˌɪt wɒz ɐ fˈIvmˈɪljən dˈɒləz dˈiːl."),
      ("It was a $1.5-billion deal.",
       "ˌɪt wʌz ɐ wˈʌn pYnt fˈIvbˈɪljən dˈɑləɹz dˈil.", "ˌɪt wɒz ɐ wˈʌn pYnt fˈIvbˈɪljən dˈɒləz dˈiːl."),
      ("It Was A $5-Million Deal.", "ˌɪt wˌʌz ɐ fˈIvmˈɪljᵊn dˈɑləɹz dˈil.", "ˌɪt wˌɒz ɐ fˈIvmˈɪljən dˈɒləz dˈiːl."),
      ("It cost $300-million today.",
       "ˌɪt kˈɔst θɹˈi hˈʌndɹəd mˈɪljᵊn dˈɑləɹz tədˈA.", "ˌɪt kˈɒst θɹˈiː hˈʌndɹəd mˈɪljən dˈɒləz tədˈA."),
      ("It cost $5-hundred today.", "ˌɪt kˈɔst fˈIv hˈʌndɹəd dˈɑləɹz tədˈA.", "ˌɪt kˈɒst fˈIv hˈʌndɹəd dˈɒləz tədˈA."),
      ("It cost $2-trillion today.", "ˌɪt kˈɔst tˈutɹˈɪljən dˈɑləɹz tədˈA.", "ˌɪt kˈɒst tˈuːtɹˈɪljən dˈɒləz tədˈA."),
      ("It cost $5-10 today.", "ˌɪt kˈɔst fˈIv dˈɑləɹztˌɛn tədˈA.", "ˌɪt kˈɒst fˈIv dˈɒləztˌɛn tədˈA."),
      ("It was a $5-one-way fare.", "ˌɪt wʌz ɐ fˈIv dˈɑləɹzwˈʌnwˈA fˈɛɹ.", "ˌɪt wɒz ɐ fˈIv dˈɒləzwˈʌnwˈA fˈɛː."),
      // Nor is a hyphen before a word that is no number, or one with spaces round it or two of them, which
      // is a dash.
      ("It is a $5-a-day habit.", "ˌɪt ɪz ɐ fˈIv dˈɑləɹzɐdˈA hˈæbət.", "ˌɪt ɪz ɐ fˈIv dˈɒləzɐdˈA hˈabɪt."),
      ("It cost $5 - million more.", "ˌɪt kˈɔst fˈIv dˈɑləɹz — mˈɪljᵊn mˈɔɹ.", "ˌɪt kˈɒst fˈIv dˈɒləz — mˈɪljən mˈɔː."),
      ("It cost $5--million today.", "ˌɪt kˈɔst fˈIv dˈɑləɹz—mˈɪljᵊn tədˈA.", "ˌɪt kˈɒst fˈIv dˈɒləz—mˈɪljən tədˈA.")
    ])
  }

  /// The texts of the tokens that come back from `retokenize` carrying the
  /// currency, for a "$" and the tokens after it handed over under the tags
  /// given, glued. A sentence reaches only the tags the tagger gives it.
  private static func amounts(after parts: [(text: String, tag: String)]) -> [String] {
    let all = [(text: "$", tag: "$")] + parts
    let source = all.map(\.text).joined()
    var start = source.startIndex
    var pennTags: PennTagMap = [:]
    let tokens = all.map { part in
      let end = source.index(start, offsetBy: part.text.count)
      let token = MToken(
        text: part.text, tokenRange: start..<end, tag: SpacyEnglishTagger.lexicalClass(for: part.tag), whitespace: ""
      )
      pennTags[ObjectIdentifier(token)] = part.tag
      start = end
      return token
    }
    let words = EnglishG2P(british: false).retokenize(tokens, pennTags: &pennTags)
    let flat = words.flatMap { word in (word as? [MToken]) ?? [word as? MToken].compactMap { $0 } }
    return flat.filter { $0.`_`.currency != nil }.map(\.text)
  }

  /// The run is carried across one hyphen, whatever the tagger called it,
  /// and to a scale only where the tagger calls it a number: under any other
  /// tag nothing past the hyphen would take the currency, so the figure
  /// keeps it. Two hyphens are a dash, and under a symbol's tag they end the
  /// amount as any token that is no number does.
  @Test func theRunCrossesOneHyphenToAScaleTheTaggerCallsANumber() {
    for hyphen in ["HYPH", "SYM", ":"] {
      #expect(Self.amounts(after: [("5", "CD"), ("-", hyphen), ("million", "CD")]) == ["million"], "under \(hyphen)")
      #expect(Self.amounts(after: [("5", "CD"), ("-", hyphen), ("Trillion", "CD")]) == ["Trillion"], "under \(hyphen)")
      #expect(Self.amounts(after: [("5", "CD"), ("-", hyphen), ("million", "NN")]) == ["5"], "under \(hyphen)")
      #expect(Self.amounts(after: [("5", "CD"), ("-", hyphen), ("dozen", "CD")]) == ["5"], "under \(hyphen)")
    }
    #expect(Self.amounts(after: [("--", "SYM"), ("5", "CD")]).isEmpty)
    #expect(Self.amounts(after: [("-", "SYM"), ("5", "CD")]) == ["5"])
  }
}
