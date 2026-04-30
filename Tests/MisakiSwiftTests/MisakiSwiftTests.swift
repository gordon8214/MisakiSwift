import Foundation
import Testing
@testable import MisakiSwift

let texts: [(originalText: String, britishPhonetization: String, americanPhoneitization: String)] = [
  ("[Misaki](/misˈɑki/) is a G2P engine designed for [Kokoro](/kˈOkəɹO/) models.",
   "misˈɑki ɪz ɐ ʤˈiːtəpˈiː ˈɛnʤɪn dɪzˈInd fɔː kˈOkəɹO mˈɒdᵊlz.",
   "misˈɑki ɪz ɐ ʤˈitəpˈi ˈɛnʤən dəzˈInd fɔɹ kˈOkəɹO mˈɑdᵊlz."),
  ("“To James Mortimer, M.R.C.S., from his friends of the C.C.H.,” was engraved upon it, with the date “1884.”",
   "“tə ʤˈAmz mˈɔːtɪmə, ˌɛmˌɑːsˌiːˈɛs, fɹɒm hɪz fɹˈɛndz ɒv ðə sˌiːsˌiːˈAʧ,” wɒz ɪnɡɹˈAvd əpˈɒn ɪt, wɪð ðə dˈAt “ˌAtˈiːn ˈAti fˈɔː.”",
   "“tə ʤˈAmz mˈɔɹTəməɹ, ˌɛmˌɑɹsˌiˈɛs, fɹʌm hɪz fɹˈɛndz ʌv ðə sˌisˌiˈAʧ,” wʌz ɪnɡɹˈAvd əpˈɑn ɪt, wɪð ðə dˈAt “ˌAtˈin ˈATi fˈɔɹ.”")
]

@Test func testStrings_BritishPhonetization() async throws {
  let englishG2P = EnglishG2P(british: true)
  
  for pair in texts {
    #expect(englishG2P.phonemize(text: pair.0).0 == pair.1)
  }
}

@Test func testStrings_AmericanPhonetization() async throws {
  let englishG2P = EnglishG2P(british: false)

  for pair in texts {
    #expect(englishG2P.phonemize(text: pair.0).0 == pair.2)
  }
}

// Retokenize Currency Index Fix Tests
@Test func testRetokenize_CurrencyWithFollowingTokens() async throws {
  let englishG2P = EnglishG2P(british: true)
  let (result, _) = englishG2P.phonemize(text: "$50 is the price for this item")
  #expect(!result.isEmpty)
  #expect(result.contains("dˈɒlə"))  // "dollar" phoneme should be present
}

// Currency appearing mid-sentence with multiple tokens before and after
@Test func testRetokenize_CurrencyInMiddleOfSentence() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "The total cost was $100 and we paid it yesterday")
  #expect(!result.isEmpty)
  #expect(result.contains("dˈɑləɹz"))  // American "dollar" phoneme
}

// Multiple currency symbols trigger the currency code path multiple times
@Test func testRetokenize_MultipleCurrenciesInText() async throws {
  let englishG2P = EnglishG2P(british: true)
  let (result, _) = englishG2P.phonemize(text: "I exchanged $200 for €150 at the bank today")
  #expect(!result.isEmpty)
  #expect(result.contains("dˈɒlə"))    // "dollar" phoneme
  #expect(result.contains("jˈʊəɹQz"))  // "euro" phoneme
}

// A hyphen between two alphabetic tokens (no whitespace on either side) must
// NOT emit the em-dash phoneme — doing so causes Kokoro to insert an audible
// pause on compound words like "on-device".
@Test func testHyphen_JoiningCompoundHasNoEmDash() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "on-device inference")
  #expect(!result.isEmpty)
  #expect(!result.contains("—"))
}

@Test func testHyphen_MultiHyphenCompoundHasNoEmDash() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "state-of-the-art model")
  #expect(!result.isEmpty)
  #expect(!result.contains("—"))
}

// A real em-dash surrounded by words must still emit the pause phoneme.
@Test func testHyphen_EmDashBetweenWordsStillPauses() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "He said—goodbye.")
  #expect(result.contains("—"))
}

// A hyphen flanked by whitespace reads as a mid-sentence dash, not a joiner.
@Test func testHyphen_SpacedHyphenStillPauses() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "first - second")
  #expect(result.contains("—"))
}

// A forced-phoneme span whose grapheme gets split by NLTagger into several
// subtokens (e.g. "COVID-19" → ["COVID", "-", "19"]) must emit the phoneme
// exactly once. Pre-fix, feature alignment assigned the full phoneme to each
// overlapping subtoken and mergeTokens concatenated all three copies.
@Test func testForcedPhoneme_HyphenatedSpanEmittedOnce() async throws {
  let englishG2P = EnglishG2P(british: false)
  let phoneme = "kˈoʊvɪd naɪnˈtiːn"
  let input = "[COVID-19](/\(phoneme)/) is the virus."
  let (result, _) = englishG2P.phonemize(text: input)
  let count = result.components(separatedBy: phoneme).count - 1
  #expect(count == 1, "phoneme appeared \(count) times; expected 1. Full output: \(result)")
}

// Same scenario on a pure number-letter split without a hyphen character
// (e.g. "iPhone17" → ["i", "Phone", "17"] via NLTagger's camelCase/digit
// boundaries). Verifies the fix generalises beyond hyphens.
@Test func testForcedPhoneme_AlphaNumSpanEmittedOnce() async throws {
  let englishG2P = EnglishG2P(british: false)
  let phoneme = "ˈaɪfoʊn sɛvənˈtin"
  let input = "Got my [iPhone17](/\(phoneme)/) today."
  let (result, _) = englishG2P.phonemize(text: input)
  let count = result.components(separatedBy: phoneme).count - 1
  #expect(count == 1, "phoneme appeared \(count) times; expected 1. Full output: \(result)")
}

// A decimal like "25.10" or "6.17" must not be silently mapped to an empty
// phoneme by getSpecialCase's dotted-acronym branch. Pre-fix, any N.N where
// both sides had <3 digits fell into getNNP, which returned an empty
// phoneme because the token had no letters — dropping the number entirely.
@Test func testDecimal_NotSilencedByAcronymBranch() async throws {
  let englishG2P = EnglishG2P(british: false)
  for input in ["Ubuntu 25.10", "kernel 6.17", "6.12", "24.04", "5.17"] {
    let (result, _) = englishG2P.phonemize(text: input)
    #expect(!result.isEmpty, "empty phoneme for '\(input)'")
    #expect(result.contains("pˈɔɪnt"), "missing 'point' for '\(input)': \(result)")
  }
}

// Real dotted acronyms must still hit the getNNP path and produce a
// letter-by-letter reading.
@Test func testDottedAcronym_StillSpelledOut() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "C.C.H. was engraved")
  #expect(result.contains("sˌiːsˌiːˈAʧ") || result.contains("sˌisˌiˈAʧ"),
          "acronym reading regressed: \(result)")
}

// extend_num's non-escape branch only split num2Words output on space, so
// hyphenated cardinals like "twenty-five" stayed intact. The lexicon has no
// entry for "twenty-five" so lookup fell into getNNP, which compactMaps non-
// letters away and returns the letter-by-letter spelling ("T-W-E-N-T-Y-F-I-V-E").
// For "$25" that surfaces as each letter spoken individually, followed by
// "Dollars" from the currency suffix loop. Asserting the absence of the
// letter-Y phoneme ("wˈaɪ") catches the regression — Y appears only when
// "twenty-five" is spelled out, never in its cardinal phonemization.
@Test func testCurrency_DollarTwentyFiveNotSpelledOut() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "Pay $25 for early access today")
  #expect(!result.isEmpty)
  #expect(result.contains("dˈɑləɹz"))
  #expect(!result.contains("wˈaɪ"), "letter-Y phoneme leaked from spell-out fallback: \(result)")
}

@Test func testCurrency_DollarTwentyFiveNotSpelledOut_British() async throws {
  let englishG2P = EnglishG2P(british: true)
  let (result, _) = englishG2P.phonemize(text: "Pay $25 for early access today")
  #expect(!result.isEmpty)
  #expect(result.contains("dˈɒlə"))
  #expect(!result.contains("wˈaɪ"), "letter-Y phoneme leaked from spell-out fallback: \(result)")
}

// Non-currency sentence-internal two-digit numbers hit the same buggy
// extend_num path (is_head=false, no currency, count<=3 → `extend_num(num)`
// without escape). Verify the fix covers that route too.
@Test func testCardinal_SentenceInternalTwentyFiveNotSpelledOut() async throws {
  let englishG2P = EnglishG2P(british: false)
  let (result, _) = englishG2P.phonemize(text: "I have 25 cats")
  #expect(!result.isEmpty)
  #expect(!result.contains("wˈaɪ"), "letter-Y phoneme leaked from spell-out fallback: \(result)")
}

// EnglishNum2Word's midNumWords table was missing (20, "twenty"), so
// toCardinal(21..29) fell into the `tensWord = ""` default and returned
// "-five", "-six", etc. extend_num(..., escape: true) then split on the
// leading non-letter "-", yielding just the ones word — so "25.10" read
// as "five point one" instead of "twenty-five point one".
@Test func testNum2Word_TwentiesCardinals() async throws {
  let num2Words = EnglishNum2Word()
  let expectations: [(Decimal, String)] = [
    (21, "twenty-one"),
    (25, "twenty-five"),
    (29, "twenty-nine"),
    (25.1, "twenty-five point one"),
    (24.04, "twenty-four point zero four"),
  ]
  for (input, expected) in expectations {
    let actual = num2Words.convert(input)
    #expect(actual == expected, "convert(\(input)) == '\(actual)', expected '\(expected)'")
  }
}
