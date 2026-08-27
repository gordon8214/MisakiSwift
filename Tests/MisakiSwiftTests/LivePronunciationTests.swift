import Testing
@testable import MisakiSwift

struct LivePronunciationTests {
  @Test func livePronunciationFollowsSentenceContext() {
    let fixtures: [(text: String, expected: String)] = [
      ("You may also get a reprieve if you have an older device that doesn't meet " +
       "Gemini's minimum specifications or if you live in a region where Gemini is not supported.",
       "lˈɪv"),
      ("Watch the live video.", "lˈIv"),
      ("The event is live now.", "lˈIv"),
      // A coordination the tagger reads as a second verb phrase: it tags
      // "live" VERB outright, so only an attributive right context recovers
      // the /laɪv/ reading here.
      ("The team looked at air pollution data from the Environmental Protection " +
       "Agency and live birth records.",
       "lˈIv"),
      ("The agency tracked emissions and live birth outcomes together.", "lˈIv"),
      // Plurals and participles are their own list members, not stems.
      ("The channel added live streaming of the hearing.", "lˈIv"),
      ("The clinic stocks live attenuated vaccines.", "lˈIv"),
      // The reported sentence: `to` makes the tagger call "live" a verb even
      // though it modifies "malware" and means active.
      ("A few dozen companies, some of them Fortune 500s, are among those that " +
       "executed proof-of-concept code. At least one misconfigured site is directing " +
       "visitors, human or AI, to live malware.",
       "lˈIv"),
      // The other bound on the list: a word that can follow the VERB must
      // stay out of it. "round" here is British for "around".
      ("They live round the corner from the school.", "lˈɪv"),
      // The attributive right context must not reach past a sentence boundary
      // and unsay a correctly tagged verb.
      ("Long may you live. Music played on into the night.", "lˈɪv"),
      ("They live. Malware spreads.", "lˈɪv")
    ]
    let g2p = EnglishG2P(british: false)

    for fixture in fixtures {
      let tokens = g2p.phonemize(text: fixture.text).1
      let liveTokens = tokens.filter { $0.text.lowercased() == "live" }
      #expect(liveTokens.count == 1, "expected one live token in \(fixture.text.debugDescription)")
      #expect(liveTokens.first?.phonemes == fixture.expected,
              "wrong live pronunciation in \(fixture.text.debugDescription)")
    }
  }
}
