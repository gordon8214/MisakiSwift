import Foundation
import Testing
@testable import MisakiSwift

// Golden parity against the real server.
//
// Expected values were captured from Kokoro-FastAPI's /dev/phonemize on the
// deployed host — the same misaki 0.9.4 that produces the audio BetterTTS is
// being compared against — not from this implementation. That is what makes
// this an oracle rather than a snapshot of our own behaviour.
//
// Regenerate with:
//   ssh gordon@dragon.ghbweb.com -p 2222 'python3 -' < capture.py
// posting {"text": ..., "language": "a"} to http://localhost:8880/dev/phonemize.
//
// Per the repo convention for the ArticleTextProjection oracle: a mismatch here
// is a bug in this implementation, never a fixture to edit. If a divergence is
// ever deliberate, mirror it on both sides AND pin it with a direct assertion —
// parity alone cannot catch both sides moving together.
//
// FIXTURES DELIBERATELY EXCLUDED — two reasons, kept apart because they mean
// different things.
//
// (a) /dev/phonemize is not a valid oracle for the input:
//
//  1. "First sentence.\nSecond sentence." — the endpoint splits on newlines and
//     returns only the first chunk, so it reports less than it synthesizes.
//     Covered instead by newlineIsIndistinguishableFromASpace.
//  2. "It cost $1234.56 today." — the endpoint applies the server's
//     normalize_text first. That layer lives in BetterTTS (TextNormalizer), not
//     here, so comparing raw misaki against it measures the wrong thing.
//  3. "Call 555-123-4567 now." and 4. "It grew 5-10 percent." — the server's
//     phone/range normalization did NOT fire on this endpoint, and the residual
//     gap is a stress-marker difference in number sequences (server ˌ where we
//     emit ˈ). Real, subtle, and worth its own investigation; not pinned here
//     because the oracle is inconsistent for these shapes.
//
// (b) The oracle is valid and we knowingly differ, because NLTagger cannot
//     supply the distinction spaCy does. Each is pinned with withKnownIssue at
//     the named test, so it fires when a finer POS source lands:
//
//  5. "Yesterday I read the book." — PortParityTests,
//     pastTenseReadIsAKnownNLTaggerLimitation.
//  6. "Plan A worked." and "Section A of the report." (server: plˈæn ˈA wˈɜɹkt.
//     / sˈɛkʃən ˈA ʌv ðə ɹəpˈɔɹt.) — DeterminerTagTests,
//     letterNamesTaggedDeterminerAreAKnownLimitation. NLTagger calls both of
//     those "A" `.determiner`, which is also what upstream's `tag == 'DT'` gate
//     keys on, so this is a shared limitation and not a cost of inverting the
//     default in Lexicon.getSpecialCase. Letter names the tagger calls `.noun`
//     ("Plan A.", "point A to point B") do agree with the server.

struct ServerParityTests {

  static let fixtures: [(text: String, server: String)] = [
    ("That is all I have.",
     "ðˈæt ɪz ˈɔl ˌI hˈæv."),
    ("Come if you could.",
     "kˈʌm ɪf ju kˈʊd."),
    ("I have been there.",
     "ˌI hæv bɪn ðˈɛɹ."),
    ("Go straight through.",
     "ɡˌO stɹˈAt θɹˈu."),
    ("This is what it was.",
     "ðˌɪs ɪz wˌʌt ɪt wʌz."),
    ("Please read the book.",
     "plˈiz ɹˈid ðə bˈʊk."),
    ("I like that book.",
     "ˌI lˈIk ðˈæt bˈʊk."),
    ("He used to run.",
     "hˌi jˈust tə ɹˈʌn."),
    ("The wound had healed.",
     "ðə wˈund hæd hˈild."),
    ("Alpha     beta.",
     "ˈælfə bˈATə."),
    ("The result (a good one) arrived.",
     "ðə ɹəzˈʌlt (ɐ ɡˈʊd wˈʌn) əɹˈIvd."),
    ("A new study describes a mechanism.",
     "ɐ nˈu stˈʌdi dəskɹˈIbz ɐ mˈɛkənˌɪzəm."),
    ("He bought a car. A truck followed.",
     "hˌi bˈɔt ɐ kˈɑɹ. ɐ tɹˈʌk fˈɑlOd."),
    ("Apple hired a new engineer in Cupertino.",
     "ˈæpᵊl hˈIəɹd ɐ nˈu ˌɛnʤənˈɪɹ ɪn kˌupəɹtˈinO."),
    // A typographic quote must not read as a phrase break. All three of these
    // turn on `nonQuotePunctuations` excluding “ ” as upstream does: the first
    // two on the following-vowel forms of "the"/"to", the third on the article.
    ("The \u{201C}apple\u{201D} tree grew.",
     "ði \u{201C}ˈæpᵊl\u{201D} tɹˈi ɡɹˈu."),
    ("They want to \u{201C}open\u{201D} it.",
     "ðˌA wˈɑnt tʊ \u{201C}ˈOpᵊn\u{201D} ɪt."),
    ("A \u{201C}smart\u{201D} speaker arrived.",
     "ɐ \u{201C}smˈɑɹt\u{201D} spˈikəɹ əɹˈIvd."),
    ("Up 50% today.",
     "ˌʌp fˈɪfti pəɹsˈɛnt tədˈA."),
    ("Fish & chips.",
     "fˈɪʃ ænd ʧˈɪps."),
    ("C++ code.",
     "sˈi plˈʌs plˈʌs kˈOd."),
    ("Wait, really? Yes!",
     "wˈAt, ɹˈiᵊli? jˈɛs!"),
    ("It cost $25 today.",
     "ˌɪt kˈɔst twˈɛnti fˈIv dˈɑləɹz tədˈA."),
    ("Meet at 3:30pm sharp.",
     "mˈit æt θɹˈi:θˈɜɹTi pˌiˈɛm ʃˈɑɹp."),
    ("Published in 1984.",
     "pˈʌblɪʃt ɪn nˌIntˈin ˈATi fˈɔɹ."),
    ("Pi is 3.14 exactly.",
     "pˈI ɪz θɹˈi pYnt wˈʌn fˈɔɹ ɪɡzˈæktli."),
    ("Choose option(s) now.",
     "ʧˈuz ˈɑpʃən(ˈɛs) nˈW."),
    ("Email bob.smith@example.com please.",
     "ˈimˌAl bˈɑb smˈɪθ æt ɪɡzˈæmpəl kˈɑm plˈiz."),
    ("The quick brown fox jumps over the lazy dog.",
     "ðə kwˈɪk bɹˈWn fˈɑks ʤˈʌmps ˈOvəɹ ðə lˈAzi dˈɔɡ."),
    ("Researchers at the university published their findings last week.",
     "ɹəsˈɜɹʧəɹz æt ðə jˌunəvˈɜɹsəTi pˈʌblɪʃt ðɛɹ fˈIndɪŋz lˈæst wˈik."),
    ("She said the results were, in her words, deeply surprising.",
     "ʃˌi sˈɛd ðə ɹəzˈʌlts wɜɹ, ɪn hɜɹ wˈɜɹdz, dˈipli səɹpɹˈIzɪŋ."),
    ("Watch the live video.",
     "wˈɑʧ ðə lˈIv vˈɪdiO."),
    ("The event is live now.",
     "ði əvˈɛnt ɪz lˈIv nˈW."),
    ("You may also get a reprieve if you have an older device that doesn't meet " +
     "Gemini's minimum specifications or if you live in a region where Gemini is not supported.",
     "jˌu mˈA ˈɔlsO ɡɛt ɐ ɹəpɹˈiv ɪf ju hæv ɐn ˈOldəɹ dəvˈIs ðæt dˈʌzᵊnt mˈit " +
     "ʤˈɛmənˌIz mˈɪnəməm spˌɛsəfəkˈAʃənz ɔɹ ɪf ju lˈɪv ɪn ɐ ɹˈiʤᵊn wˌɛɹ " +
     "ʤˈɛmənˌI ɪz nˌɑt səpˈɔɹTᵻd."),
  ]

  @Test func localPhonemesMatchTheServerExactly() async throws {
    let g2p = EnglishG2P(british: false)
    for (text, expected) in Self.fixtures {
      let actual = g2p.phonemize(text: text).0
      #expect(actual == expected,
              "phoneme divergence\n  input : \(text.debugDescription)\n  server: \(expected)\n  local : \(actual)")
    }
  }
}
