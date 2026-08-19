import Testing
@testable import MisakiSwift

/// A possessive clitic that follows a `[word](/ipa/)` span.
///
/// The span sets `phonemes` directly, so `retokenize` gives that token a group
/// of its own and the `'s` is no longer in the stem's subtoken group. It was
/// then resolved alone, as a Particle, and came back as a literal `s` — the
/// one clitic whose phoneme is conditioned on the sound before it. Without
/// markup the whole of `dog's` stays one token and `stem_s` applies
/// `pluralizeS`, which is why only the forced path was wrong.
struct ForcedSpanPossessiveTests {

  /// The oracle is the lexicon's own reading of the same word: the clitic is a
  /// property of the stem's final phoneme and nothing else, so forcing a stem
  /// to exactly what the lexicon holds must reproduce the lexicon's whole
  /// output. Each dialect forces ITS OWN stem for that reason — forcing
  /// `dˈɔɡ` under a British voice is a different word, not a failure here.
  ///
  /// Every voicing class, because a voiceless final was right by accident all
  /// along and the reported case alone would not have caught the sibilants.
  @Test func aForcedSpanTakesTheSameCliticTheLexiconWould() {
    let fixtures: [(bare: String, forced: String, british: Bool, expected: String)] = [
      // Voiced final: lost its voicing outright (was `dˈɔɡs` / `dˈɒɡs`).
      ("the dog's bone", "the [dog](/dˈɔɡ/)'s bone", false, "ðə dˈɔɡz bˈOn"),
      ("the dog's bone", "the [dog](/dˈɒɡ/)'s bone", true, "ðə dˈɒɡz bˈQn"),
      // Sibilant final: was a doubled sibilant with no epenthetic vowel
      // (`bˈʌss`), which is the case `pluralizeS` exists for.
      ("the bus's route", "the [bus](/bˈʌs/)'s route", false, "ðə bˈʌsᵻz ɹˈut"),
      ("the bus's route", "the [bus](/bˈʌs/)'s route", true, "ðə bˈʌsɪz ɹˈuːt"),
      ("the judge's ruling", "the [judge](/ʤˈʌʤ/)'s ruling", false, "ðə ʤˈʌʤᵻz ɹˈulɪŋ"),
      ("the judge's ruling", "the [judge](/ʤˈʌʤ/)'s ruling", true, "ðə ʤˈʌʤɪz ɹˈuːlɪŋ"),
      // Voiceless finals, which were already right and must stay put.
      ("the cat's bowl", "the [cat](/kˈæt/)'s bowl", false, "ðə kˈæts bˈOl"),
      ("the smith's forge", "the [smith](/smˈɪθ/)'s forge", false, "ðə smˈɪθs fˈɔɹʤ"),
      ("the smith's forge", "the [smith](/smˈɪθ/)'s forge", true, "ðə smˈɪθs fˈɔːʤ")
    ]

    for fixture in fixtures {
      let g2p = EnglishG2P(british: fixture.british)
      #expect(g2p.phonemize(text: fixture.forced).0 == fixture.expected,
              "wrong reading for \(fixture.forced.debugDescription)")
      #expect(g2p.phonemize(text: fixture.bare).0 == fixture.expected,
              "the lexicon and the forced span disagree for \(fixture.bare.debugDescription)")
    }
  }

  /// A multi-word forced span ends on its LAST phoneme, so the clitic has to
  /// read that rather than the span's first group. `ˈɛɹ bˈi ˈɛn bˈi` ends
  /// voiced and takes `z`; it was `bˈis`.
  @Test func aMultiWordSpanIsJudgedByItsFinalPhoneme() {
    let g2p = EnglishG2P(british: false)
    #expect(g2p.phonemize(text: "An [Airbnb](/ˈɛɹ bˈi ˈɛn bˈi/)'s price.").0
              == "ɐn ˈɛɹ bˈi ˈɛn bˈiz pɹˈIs.")
  }

  /// The curly apostrophe publishers actually emit, which is why the clitic
  /// set is not just `'s` — a straight-only match would leave every real
  /// article on the old reading.
  @Test func theCurlyApostropheIsCoveredToo() {
    let g2p = EnglishG2P(british: false)
    #expect(g2p.phonemize(text: "the [dog](/dˈɔɡ/)\u{2019}s bone").0 == "ðə dˈɔɡz bˈOn")
  }

  /// The bound: only a clitic whose phoneme depends on what precedes it is
  /// re-derived. `'d` / `'ll` / `'re` / `'ve` are fixed strings, so they are
  /// left exactly as they were — these values are byte-identical before and
  /// after the change.
  ///
  /// They are NOT the bare readings, and deliberately so: a forced span breaks
  /// the contraction out of its lexicon entry entirely (`they're` is `ðɛɹ`,
  /// `[they](/ðˈA/)'re` is `ðˈAɹˌA`), which is the same group-splitting root
  /// cause reaching a different clitic class. That is a separate defect with
  /// no reported symptom and a much larger fix — pinned here so it cannot
  /// drift silently, not endorsed.
  @Test func theFixedCliticsAreLeftAlone() {
    let fixtures: [(text: String, expected: String)] = [
      ("[they](/ðˈA/)'ll go", "ðˈAəl ɡˌO"),
      ("[they](/ðˈA/)'ve gone", "ðˈAvˈiv ɡˈɔn"),
      ("[they](/ðˈA/)'re here", "ðˈAɹˌA hˈɪɹ"),
      ("[they](/ðˈA/)'d go", "ðˈAd ɡˌO")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      #expect(g2p.phonemize(text: fixture.text).0 == fixture.expected,
              "\(fixture.text.debugDescription) moved")
    }
  }
}
