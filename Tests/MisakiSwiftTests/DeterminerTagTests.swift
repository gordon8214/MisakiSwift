import Foundation
import NaturalLanguage
import Testing
@testable import MisakiSwift

// The indefinite article "a" versus the letter name "A".
//
// Upstream misaki reads a bare "a"/"A" as the LETTER NAME unless spaCy tagged it
// DT (en.py:174-175 — `return 'ɐ' if tag == 'DT' else 'ˈA', 4`). In misaki's
// alphabet "A" is /eɪ/, so the else branch is a primary-stressed "AY" — which is
// exactly how English marks an *emphatic* article, and therefore reads to a
// listener as misplaced emphasis rather than as a wrong vowel.
//
// This port feeds that branch Apple's NLTagger, so `Lexicon.getSpecialCase`
// inverts the default: article unless the tag is positively `.noun`. These tests
// are the corpus that rule was derived from, and the net that holds it.
//
// A note on what is and isn't a regression net here: on macOS, NLTagger returns
// `.determiner` for the article in every context below, so the plain probes pass
// on the pre-inversion code too. The rows that actually discriminate are the
// mid-phrase-punctuation ones in `articleFollowedByAMidPhraseMark` — those were
// broken by the first attempt at this rule — and the whole file is what keeps a
// future attempt from trading one class of error for another.

private struct Probe {
  let text: String
  let why: String
  /// The surface forms in `text` that are articles. "Section A of a report."
  /// carries a letter name too, and that letter has to be named explicitly
  /// rather than assumed, because we deliberately voice it as the article
  /// (pinned in `letterNamesTaggedDeterminerAreAKnownLimitation`).
  let articleForms: Set<String>

  init(_ text: String, _ why: String, articleForms: Set<String> = ["a", "A"]) {
    self.text = text
    self.why = why
    self.articleForms = articleForms
  }
}

private let probes: [Probe] = [
  Probe("This is a new study.", "plain mid-sentence"),
  Probe("A new study shows the effect.", "sentence-initial capital A"),
  Probe("The result (a good one) arrived.", "after an open paren"),
  Probe("Apple hired a new engineer in Cupertino.", "article adjacent to NER spans"),
  Probe("\"It was a mistake,\" she said.", "inside ASCII quotes"),
  Probe("He bought a car. A truck followed.", "two articles, one capitalized"),
  Probe("Section A of a report.", "letter name and article in one string", articleForms: ["a"]),
  Probe("a new study shows", "chunk-edge fragment, no terminator"),
  Probe("It was described as a", "article stranded at a chunk seam")
]

// The rows that discriminate. `EnglishG2P.tokenContext` clears `futureVowel` for
// ANY member of `nonQuotePunctuations` — `; : , . ! ? — …` — not just for a
// sentence terminator, so any rule keyed on "nothing follows" reads these as
// phrase-final and voices the emphatic article. Curly quotes belong to that set
// only when `nonQuotePunctuations` diverges from upstream, which it no longer
// does; the ASCII-quote row above passed even then, which is why the original
// corpus missed all of this.
private let midPhraseMarkProbes: [Probe] = [
  Probe("A \u{201C}smart\u{201D} speaker arrived.", "article before an opening curly quote"),
  Probe("A \u{2018}quiet\u{2019} room appeared.", "article before a single curly quote"),
  Probe("A \u{2014} rare \u{2014} solution.", "article before an em dash"),
  Probe("A - rare - solution.", "article before a spaced hyphen, which phonemizes as a dash"),
  Probe("A \u{2026} long pause followed.", "article before an ellipsis")
]

// MARK: - Diagnostic

// Not an assertion — a dump of what NLTagger actually returns for the "a"/"A"
// tokens in each probe, so the rule in `getSpecialCase` stays derived from
// measurement. `.nameTypeOrLexicalClass` is a HYBRID scheme: whenever Apple's
// NER claims a span it returns a name-type tag INSTEAD of the lexical class,
// which is why only the lexical `.noun` counts as evidence there.
@Test func reportNLTaggerTagsForTheArticle() async throws {
  let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
  for probe in probes + midPhraseMarkProbes {
    let text = probe.text
    tagger.string = text
    tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
    var seen: [String] = []
    tagger.enumerateTags(
      in: text.startIndex..<text.endIndex,
      unit: .word,
      scheme: .nameTypeOrLexicalClass,
      options: []
    ) { tag, range in
      let word = String(text[range])
      if word == "a" || word == "A" {
        seen.append("\(word)=\(tag?.rawValue ?? "<nil>")")
      }
      return true
    }
    print("NLTAG [\(seen.joined(separator: " "))] \(probe.why): \(text.debugDescription)")
  }
}

// MARK: - The article must never be voiced as the letter name

// Asserted against the returned [MToken], not the joined string, so this also
// rules out the one alternative failure mode: if "a" were being folded into a
// neighbouring token, `word` would never equal "a" and `getSpecialCase` would
// never run at all.
private func expectArticlesAreSchwa(_ probe: Probe, file: String = #file) {
  let g2p = EnglishG2P(british: false)
  let (phonemes, tokens) = g2p.phonemize(text: probe.text)
  let articles = tokens.filter { probe.articleForms.contains($0.text) }

  #expect(!articles.isEmpty,
          """
          no standalone article token survived tokenization — \(probe.why)
            input : \(probe.text.debugDescription)
            tokens: \(tokens.map(\.text))
          """)

  for token in articles {
    #expect(token.phonemes == "ɐ",
            """
            article voiced as \(token.phonemes ?? "<nil>"), expected ɐ — \(probe.why)
              input : \(probe.text.debugDescription)
              output: \(phonemes)
            """)
  }
}

@Test func articleIsNeverVoicedAsTheLetterName() async throws {
  for probe in probes { expectArticlesAreSchwa(probe) }
}

@Test func articleFollowedByAMidPhraseMark() async throws {
  for probe in midPhraseMarkProbes { expectArticlesAreSchwa(probe) }
}

// Article-shaped input: multi-sentence, hard-wrapped the way a publisher wraps
// markup, carrying a place name and a word whose own phonemes contain /eɪ/ — the
// shape that actually reaches the engine, as opposed to a one-line fixture.
@Test func articleShapedChunkVoicesEveryArticleAsSchwa() async throws {
  let wrapped = """
  A new study published this week describes a mechanism
  that had been a puzzle for decades. The authors,
  working at a laboratory in Cambridge, built a model of
  a single cell and ran a simulation against it. A
  colleague called the result a milestone.
  """
  // Derived, not restated: an off-by-one in the literal above should read as a
  // tokenization failure, not as a stale expectation.
  let expected = wrapped.split(whereSeparator: \.isWhitespace).filter { $0 == "a" || $0 == "A" }.count
  for british in [false, true] {
    let g2p = EnglishG2P(british: british)
    let (phonemes, tokens) = g2p.phonemize(text: wrapped)
    let articles = tokens.filter { $0.text == "a" || $0.text == "A" }
    #expect(articles.count == expected,
            "expected \(expected) article tokens, got \(articles.map(\.text))")
    for token in articles {
      #expect(token.phonemes == "ɐ",
              "article voiced as \(token.phonemes ?? "<nil>") (british: \(british)): \(phonemes)")
    }
  }
}

// MARK: - The letter name must survive where the tagger supports it

// The guard that stops the inversion from becoming "the letter A no longer
// exists". Asserted on the token rather than with `phonemes.contains("ˈA")`,
// which is a weak oracle — "ˈA" occurs inside ordinary words in this alphabet
// (wˈAt, tədˈA), so a substring check can pass on the wrong token entirely.
@Test func capitalAWithANominalTagReadsAsTheLetterName() async throws {
  let g2p = EnglishG2P(british: false)
  for text in ["Plan A.",
               "See Exhibit A.",
               "Exhibit A was entered into evidence.",
               "She got an A on the test.",
               "Go from point A to point B.",
               "He owns Class A shares.",
               "Series A funding closed.",
               "Hepatitis A vaccine."] {
    let (phonemes, tokens) = g2p.phonemize(text: text)
    let letters = tokens.filter { $0.text == "A" }
    #expect(letters.count == 1, "expected one bare A: \(text.debugDescription) -> \(tokens.map(\.text))")
    #expect(letters.first?.phonemes == "ˈA",
            "letter name lost: \(text.debugDescription) -> \(phonemes)")
  }
}

// MARK: - Known limitations, in the style of pastTenseReadIsAKnownNLTaggerLimitation

// NLTagger calls these "A" `.determiner`, so they read as the article. NOT a
// regression from the inversion — upstream's `tag == 'DT'` gate produces exactly
// the same output on exactly these inputs, because the tag it keys on is the
// thing that is wrong. Closing them needs a finer POS source, the same wall as
// past-tense "read".
//
// withKnownIssue means this FAILS if the behaviour is ever fixed, which is the
// signal to promote these into the test above and capture them as server
// parity fixtures.
@Test func letterNamesTaggedDeterminerAreAKnownLimitation() async throws {
  let g2p = EnglishG2P(british: false)
  withKnownIssue("NLTagger reports .determiner for these letter names; needs spaCy-grade POS") {
    for text in ["Vitamin A helps.", "Section A of the report.", "Team A won.",
                 "Grade A beef.", "Plan A worked.", "The answer is A."] {
      let tokens = g2p.phonemize(text: text).1
      #expect(tokens.first { $0.text == "A" }?.phonemes == "ˈA", "\(text.debugDescription)")
    }
  }
}

// A period with no following space is a single token to NLTagger — "thing.A"
// comes back as one `.noun` — and `EnglishG2P.retokenize` builds subtokens with
// `MToken(copying:)`, which copies the parent's tag. The "A" subtoken therefore
// inherits `.noun` and takes the letter reading. Upstream has the same defect
// for the same reason, so this is a shared limitation rather than a cost of the
// inversion; it is pinned because extracted article text produces the shape.
@Test func articleFusedToAPrecedingPeriodIsAKnownLimitation() async throws {
  let g2p = EnglishG2P(british: false)
  withKnownIssue("NLTagger fuses 'thing.A' into one .noun token; the subtokens inherit that tag") {
    let (phonemes, _) = g2p.phonemize(text: "It was a thing.A new thing began.")
    #expect(!phonemes.contains("ˌA") && !phonemes.contains("ˈA"), "\(phonemes)")
  }
}
