import Foundation
import Testing
@testable import MisakiSwift

// Regression coverage for four divergences from hexgrad/misaki's en.py that the
// original Swift port carried. Each had a large audible effect in Kokoro and
// none was caught by the two golden strings the port shipped with, which is
// exactly why they are pinned individually here.

// MARK: - Phrase-final stress (en.py:229-238, the `None` tag variant)

// 32 gold entries carry a "None" key holding the *stressed* form, selected when
// `ctx.futureVowel == nil` — i.e. nothing follows, so the word is phrase-final.
// The port assigned "XX" instead of "None"; "XX" is getParentTag's nil-tag
// sentinel and matches no lexicon key, so every one of these words fell through
// to its unstressed DEFAULT at the end of a sentence.
@Test func phraseFinalFunctionWordTakesStressedNoneVariant() async throws {
  let g2p = EnglishG2P(british: false)

  // "have" — DEFAULT "hæv", None "hˈæv".
  let (final, _) = g2p.phonemize(text: "That is all I have.")
  #expect(final.contains("hˈæv"), "expected stressed phrase-final 'have': \(final)")

  // "could" — DEFAULT "kʊd", None "kˈʊd".
  let (could, _) = g2p.phonemize(text: "Come if you could.")
  #expect(could.contains("kˈʊd"), "expected stressed phrase-final 'could': \(could)")
}

// The same word mid-phrase, with a consonant-initial word after it, must keep
// the UNstressed DEFAULT. This is the guard that stops the fix from becoming
// "always take the None variant".
@Test func nonFinalFunctionWordKeepsUnstressedDefault() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "I have been there.")
  #expect(result.contains("hæv"), "expected unstressed mid-phrase 'have': \(result)")
  #expect(!result.contains("hˈæv"), "'have' should not be stressed mid-phrase: \(result)")
}

// MARK: - Homographs keyed on the raw Penn tag (en.py:231-234)

// Python tries the raw tag first and only falls back to the coarse parent tag
// when the raw tag is absent. The port called getParentTag unconditionally,
// collapsing VBD/VBN/VBP to VERB before lookup — and the gold entry for "read"
// has no VERB key at all, only VBD/VBN/VBP, so past-tense "read" could never
// resolve to anything but DEFAULT.
// The observable win: "that" as a determiner. gold: {DEFAULT: ðæt, DT: ðˈæt}.
// Apple's NLTagger does emit `.determiner`, which PennTagUtil maps to "DT", so
// the raw-tag lookup resolves. Pre-fix, getParentTag saw a tag that is neither
// VB*/NN*/ADV/ADJ and returned its "XX" sentinel, so this always took DEFAULT.
@Test func determinerTakesRawPennTagVariant() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "I like that book.")
  #expect(result.contains("ðˈæt"), "determiner 'that' should take the stressed DT variant: \(result)")
}

// "used" resolves through an explicit special case (Lexicon.swift:249-254) that
// reads m["VBD"] directly, so it works regardless of tagger granularity.
@Test func usedToTakesTheVBDVariant() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "He used to run.")
  #expect(result.contains("jˈust"), "'used to' should be /juːst/, not /juːzd/: \(result)")
}

// KNOWN GAP, deliberately pinned rather than silently tolerated.
//
// gold "read" is {ADJ: ɹˈɛd, DEFAULT: ɹˈid, VBD: ɹˈɛd, VBN: ɹˈɛd, VBP: ɹˈɛd} —
// note there is no VERB key, so the tense-specific tag is the only way in.
// Upstream misaki gets one from spaCy's en_core_web_sm, which tags "read" in
// "Yesterday I read the book." as VBD. This port resolves NLTagger's hybrid
// name/POS scheme against `.lexicalClass`, but the resulting `.verb` is still
// coarse for BOTH the past and the infinitive (verified: the tag is identical
// in the two sentences below). No amount of lookup fixing can recover the
// distinction — closing this needs a finer-grained POS source than NLTagger.
//
// Consequence: past-tense "read" is voiced /riːd/ on device and /rɛd/ on the
// server. Same for "wound" and "reread".
//
// withKnownIssue means this test FAILS if the behaviour is ever fixed, which is
// the signal to delete this block and assert the correct pronunciation.
@Test func pastTenseReadIsAKnownNLTaggerLimitation() async throws {
  let g2p = EnglishG2P(british: false)

  // Present tense is correct today and must stay correct.
  let (present, _) = g2p.phonemize(text: "Please read the book.")
  #expect(present.contains("ɹˈid"), "infinitive 'read' should be /riːd/: \(present)")

  withKnownIssue("NLTagger reports coarse .verb for both tenses; needs spaCy-grade POS") {
    let (past, _) = g2p.phonemize(text: "Yesterday I read the book.")
    #expect(past.contains("ɹˈɛd"), "past-tense 'read' should be /rɛd/: \(past)")
  }
}

// MARK: - Whitespace normalization (kokoro/pipeline.py:180-181)

// The port emitted MToken.whitespace verbatim, so a newline between sentences
// entered the phoneme string. "\n" is absent from Kokoro's vocab, so
// Tokenizer.tokenize dropped it — taking the word separator with it and fusing
// the two words. Article text is mostly line breaks, so this fired constantly.
@Test func newlineBetweenSentencesBecomesASingleSpace() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "First sentence.\nSecond sentence.")

  #expect(!result.contains("\n"), "newline leaked into phonemes: \(result)")
  #expect(!result.contains("\r"), "carriage return leaked into phonemes: \(result)")
  #expect(result.contains(" "), "word separator was lost: \(result)")
}

// The assertion that matters, and the one the weaker test above missed: a
// newline must be INDISTINGUISHABLE from a space. NLTagger does not treat a
// bare "\n" as a word boundary — it returned "alpha\nbeta" as one Noun token,
// which phonemized as a single compound word AND shifted the stress, so
// "Second" came out sˈikənd instead of sˈɛkənd. Upstream never hits this
// because KPipeline splits on `\n+` before misaki ever runs.
@Test func newlineIsIndistinguishableFromASpace() async throws {
  let g2p = EnglishG2P(british: false)
  for (newlined, spaced) in [("alpha\nbeta", "alpha beta"),
                             ("First sentence.\nSecond sentence.", "First sentence. Second sentence."),
                             ("Line one\nLine two", "Line one Line two"),
                             // CRLF is a SINGLE Character in Swift, equal to neither
                             // "\n" nor "\r", so a Character-level fold skipped it
                             // entirely — and CRLF is the common case in HTML/RSS.
                             ("alpha\r\nbeta", "alpha beta"),
                             ("First sentence.\r\nSecond sentence.", "First sentence. Second sentence."),
                             ("Line one\rLine two", "Line one Line two")] {
    let a = g2p.phonemize(text: newlined).0
    let b = g2p.phonemize(text: spaced).0
    #expect(a == b, "newline diverged from space:\n  \(newlined.debugDescription) -> \(a)\n  \(spaced.debugDescription) -> \(b)")
  }
}

@Test func runsOfWhitespaceCollapseToOneSpace() async throws {
  let g2p = EnglishG2P(british: false)
  let (spaced, _) = g2p.phonemize(text: "Alpha     beta.")
  let (single, _) = g2p.phonemize(text: "Alpha beta.")
  #expect(spaced == single, "whitespace run changed the phonemes: \(spaced) vs \(single)")
  #expect(!spaced.contains("  "), "double space survived: \(spaced)")
}

@Test func leadingAndTrailingWhitespaceIsTrimmed() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "  Hello there.\n\n")
  #expect(result == result.trimmingCharacters(in: .whitespacesAndNewlines),
          "result was not trimmed: \(result)")
}

// MARK: - Parentheses (en.py PUNCT_TAG_PHONEMES -LRB-/-RRB-)

// Kokoro's vocab carries "(" and ")" (ids 12/13), but the port's
// punctuationTagPhonemes table held only the three quote entries and the
// fallback filter set excludes parens — so they were mapped to "" and the
// parenthetical prosody was lost.
@Test func parenthesesSurviveIntoPhonemes() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "The result (a good one) arrived.")
  #expect(result.contains("("), "open paren was dropped: \(result)")
  #expect(result.contains(")"), "close paren was dropped: \(result)")
}

// MARK: - Unknown-token sentinel

// KPipeline builds misaki with unk='' (kokoro/pipeline.py:123). The port
// defaulted to "❓", which is absent from Kokoro's vocab and so was dropped at
// tokenization anyway — silently, and along with the token's separator.
@Test func unknownSentinelDefaultsToEmptyLikeKPipeline() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "Hello there.")
  #expect(!result.contains("❓"), "unresolvable-token sentinel leaked: \(result)")
}

// MARK: - Symbols with a spoken word form

// NLTagger tags % & + @ as punctuation. Neither `punctuationTagPhonemes` nor
// the `punctuactions` filter set contains them, so the punctuation branch in
// `phonemize` mapped each to "" and dropped it: "50%" was voiced "fifty", with
// "percent" silently gone. Symbols carrying a `Lexicon.symbolSet` entry now
// bypass that branch and resolve through the lexicon, as upstream misaki does.
@Test func percentIsVoicedNotDropped() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "Up 50% today.")
  #expect(result.contains("pəɹsˈɛnt"), "'percent' was dropped: \(result)")
}

@Test func ampersandBecomesAnd() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "Fish & chips.")
  #expect(result.contains("ænd"), "'&' was dropped: \(result)")
}

@Test func plusIsVoiced() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "C++ code.")
  #expect(result.contains("plˈʌs"), "'+' was dropped: \(result)")
}

// The guard must not disturb ordinary punctuation, which still has to reach
// Kokoro's vocab to drive prosody.
@Test func ordinaryPunctuationStillReachesThePhonemes() async throws {
  let g2p = EnglishG2P(british: false)
  let (result, _) = g2p.phonemize(text: "Wait, really? Yes!")
  #expect(result.contains(","))
  #expect(result.contains("?"))
  #expect(result.contains("!"))
}
