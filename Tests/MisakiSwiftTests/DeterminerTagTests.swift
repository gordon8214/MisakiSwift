import Foundation
import NaturalLanguage
import Testing
@testable import MisakiSwift

// The indefinite article "a".
//
// Upstream misaki reads a bare "a"/"A" as the LETTER NAME unless spaCy tagged it
// DT (en.py:174-175 — `return 'ɐ' if tag == 'DT' else 'ˈA', 4`). In misaki's
// alphabet "A" is /eɪ/, so the else branch is a primary-stressed "AY" — which is
// exactly how English marks an *emphatic* article, and therefore reads to a
// listener as misplaced emphasis rather than as a wrong vowel.
//
// This port feeds that branch Apple's NLTagger instead of spaCy. These tests
// exist to keep the article reading independent of how good that tagger is.

private struct Probe {
  let text: String
  let why: String
  /// The surface forms in `text` that are articles. "Section A of a report."
  /// carries both readings, so the letter has to be excluded by hand.
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
  Probe("\"It was a mistake,\" she said.", "inside quotes"),
  Probe("He bought a car. A truck followed.", "two articles, one capitalized"),
  Probe("Section A of a report.", "letter name and article in one string", articleForms: ["a"]),
  Probe("a new study shows", "chunk-edge fragment, no terminator"),
  Probe("It was described as a", "article stranded at a chunk seam")
]

// MARK: - Diagnostic

// Not an assertion — a dump of what NLTagger actually returns for the "a"/"A"
// tokens in each probe, so the branch above can be reasoned about from data
// rather than guessed at. `.nameTypeOrLexicalClass` is a HYBRID scheme: whenever
// Apple's NER claims a span it returns a name-type tag INSTEAD of the lexical
// class, so an article absorbed into an entity span can never be `.determiner`.
@Test func reportNLTaggerTagsForTheArticle() async throws {
  let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
  for probe in probes {
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

// Asserted against the returned [MToken], not just the joined string, so this
// also rules out the one alternative failure mode: if "a" were being folded into
// a neighbouring token, `word` would never equal "a" and `getSpecialCase` would
// never run at all.
@Test func articleIsNeverVoicedAsTheLetterName() async throws {
  let g2p = EnglishG2P(british: false)
  for probe in probes {
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
  for british in [false, true] {
    let g2p = EnglishG2P(british: british)
    let (phonemes, tokens) = g2p.phonemize(text: wrapped)
    let articles = tokens.filter { $0.text == "a" || $0.text == "A" }
    #expect(articles.count == 9, "expected 9 article tokens, got \(articles.map(\.text))")
    for token in articles {
      #expect(token.phonemes == "ɐ",
              "article voiced as \(token.phonemes ?? "<nil>") (british: \(british)): \(phonemes)")
    }
  }
}

// The guard that stops the fix from becoming "the letter A no longer exists".
// A capitalized, phrase-final "A" is a letter name ("Plan A.", "Exhibit A.") —
// an article is never phrase-final.
@Test func phraseFinalCapitalAKeepsTheLetterName() async throws {
  let g2p = EnglishG2P(british: false)
  for text in ["Plan A.", "See Exhibit A.", "The answer is A."] {
    let (phonemes, _) = g2p.phonemize(text: text)
    #expect(phonemes.contains("ˈA"),
            "phrase-final letter name was lost: \(text.debugDescription) -> \(phonemes)")
  }
}

// The price of the rule above, pinned directly rather than left to be discovered.
//
// ServerParityTests is a golden oracle and its header requires that a deliberate
// divergence be asserted outright, because parity alone cannot catch both sides
// moving together. This is that assertion. Captured from the deployed
// Kokoro-FastAPI /dev/phonemize, spaCy tags these "A" NNP and the server says:
//
//   "Plan A worked."           -> plˈæn ˈA wˈɜɹkt.
//   "Section A of the report." -> sˈɛkʃən ˈA ʌv ðə ɹəpˈɔɹt.
//
// We say ɐ. A non-final letter name is indistinguishable from an article
// without spaCy-grade POS, and voicing every article as a stressed "AY" is by
// far the worse of the two errors — it fires on ordinary prose constantly,
// where this fires on "Plan A"-shaped phrases only.
//
// If this test ever fails, the letter reading has been recovered: delete this
// block and move both sentences into ServerParityTests.fixtures.
@Test func nonFinalLetterNameIsADeliberateDivergence() async throws {
  let g2p = EnglishG2P(british: false)
  for text in ["Plan A worked.", "Section A of the report."] {
    let (phonemes, _) = g2p.phonemize(text: text)
    #expect(!phonemes.contains("ˈA"),
            "non-final letter name unexpectedly recovered: \(text.debugDescription) -> \(phonemes)")
    #expect(phonemes.contains("ɐ"),
            "expected the article reading: \(text.debugDescription) -> \(phonemes)")
  }
}
