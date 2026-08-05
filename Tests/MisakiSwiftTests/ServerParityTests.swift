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
// FOUR FIXTURES ARE DELIBERATELY EXCLUDED, because /dev/phonemize is not a
// valid oracle for them:
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
// "Yesterday I read the book." is excluded too — it is the known NLTagger POS
// limitation, already pinned with withKnownIssue in PortParityTests.
//
// So are "Plan A worked." and "Section A of the report." (server: plˈæn ˈA
// wˈɜɹkt. / sˈɛkʃən ˈA ʌv ðə ɹəpˈɔɹt.). Those are a DELIBERATE divergence, not a
// gap: Lexicon.getSpecialCase now defaults a bare "a"/"A" to the article and
// requires positive evidence for the letter name, because NLTagger is not
// reliable enough to be the sole gate the way spaCy's DT is. A NON-final letter
// name is what that costs, and it is pinned directly — per the rule above — by
// nonFinalLetterNameIsADeliberateDivergence in DeterminerTagTests. Phrase-final
// letter names ("Plan A.") still agree with the server.

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
