import Testing
@testable import MisakiSwift

struct LeadScrollPronunciationTests {
  // Measured at f550051: 7 of the article's 14 metal references were lˈid
  // (US) / lˈiːd (GB). Gold `led` supplies lˈɛd in both dialects.
  static let articleParagraphs = [
    """
    The Vesuvius Challenge is an ongoing project that combines "digital unwrapping" with
    crowdsourced machine learning to decipher the so-called Herculaneum scrolls, badly charred
    2000-year-old papyri too fragile to be physically unrolled. The effort just got an additional
    boost. A team of researchers created their own contemporary model papyrus scrolls—charring them
    just like the originals—to validate a screening method to determine which of the Herculaneum
    scrolls were written in lead-based ink and hence are the most promising candidates for further
    analysis. They described the process in a new paper published in the journal PLoS ONE.
    """,
    """
    Many of the inks used by Egyptian scribes contained large traces of metals, including lead,
    making them ideal for X-ray imaging. The older Herculaneum scrolls, however, were written with
    carbon-based ink (charcoal and water), so one would not get the same fluorescing in the scans;
    there is almost no difference in X-ray absorption between parts of the papyrus with ink and
    parts without ink. Searles was still able to capture minute textural differences, training an
    artificial neural network to do so.
    """,
    """
    Looking for lead-based ink.
    """,
    """
    Douglas Seiler, a retired inventor, was working with Berkeley SETI on a new telescope called
    Panoseti when he heard about the Herculaneum scrolls—as well as the poor signal-to-noise ratios
    that had been plaguing the efforts of Searles and others to digitally unwrap and decipher them.
    In 2016, scientists identified letters in two fragments of a scroll that contained lead,
    suggesting that some of the scrolls might be written in lead-based ink. So Seiler set out to
    test which of the scrolls were written with lead-based ink and put together an
    interdisciplinary team to help, including two retired Berkeley chemists and a Berkeley graduate
    student in archaeology with expertise in ancient Egyptian inks.
    """,
    """
    The authors purchased modern Egyptian papyrus, which is still prepared in a similar fashion to
    the papyrus of two millennia ago, and traditional lampblack ink from Japan. They added
    different amounts of lead nitrate to the ink to create samples with different lead
    concentrations. A team of high school students inscribed the papyri with quotes from the Bible,
    Star Wars, and the 1960s TV show The Outer Limits, among other sources, using a reed stylus
    dipped in the different inks. The model scrolls were imaged with CT scans to verify the various
    lead concentrations.
    """,
    """
    "With lead in the ink, you would get a huge friggin' signature, so you really need to be
    looking for scrolls with lead in them," Seiler said. "They're having problems reading a lot of
    them because of the low contrast of carbon ink on carbon paper. We're relatively certain that
    if they start searching for lead, or they let us search for lead, it will help this whole
    process." Even a handheld X-ray fluorescence scanner is sufficient to determine which scrolls
    would be the most promising candidates for further analysis.
    """,
    """
    "Honestly, getting here is, for me, just as unique as our research," Seiler said. "I mean,
    inorganic chemistry, papyrus, X-ray tomography, AI—it's really quite an eclectic group of
    scientists and methodology to get to the point that, yes, if there's lead in those scrolls, you
    guys will be able to read the images much better. I'll give you 10-to-1 odds. We'd like it to
    be our team, but if some other team is going to take this idea—which is OK—we don't care."
    """
  ]

  static let nonmetalContexts = [
    "They extended their lead in the ink industry.",
    "We maintained our lead in scroll research.",
    "They gained a comfortable lead in the ink industry.",
    "We searched for lead, rhythm, and bass guitarists.",
    "They searched for lead, supporting, and background actors.",
    "They will lead the team.",
    "The lead author studies ink and scrolls.",
    "They searched for lead actors.",
    "We are searching for lead authors.",
    "Search for lead guitar lessons.",
    "Search for the lead.",
    "She has the lead in the race.",
    "The team with the lead in the race won.",
    "Study metals, including iron, and lead the discussion.",
    "They lead nitrate research projects.",
    "They lead in the polls.",
    "They lead. Ink covers the scrolls.",
    "The lead in the ink industry spoke.",
    "They search. For lead actors, auditions start today."
  ]

  @Test func nearbyNonmetalUsesKeepTheirReading() throws {
    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      for text in Self.nonmetalContexts {
        let tokens = g2p.phonemize(text: text).1.filter { $0.text.lowercased() == "lead" }
        #expect(tokens.count == 1)
        #expect(tokens.first?.phonemes == (british ? "lˈiːd" : "lˈid"), "wrong guide reading in \(text)")
      }
    }
  }

  @Test func everyMetalReferenceInTheReportedArticle() throws {
    for british in [false, true] {
      let g2p = try EnglishG2P(british: british, requireRemoteFrontendParity: true)
      var count = 0
      for text in Self.articleParagraphs {
        let tokens = g2p.phonemize(text: text).1.filter { $0.text.lowercased() == "lead" }
        count += tokens.count
        for token in tokens {
          #expect(token.phonemes == "lˈɛd", "wrong metal reading in \(text): \(token.phonemes ?? "nil")")
        }
      }
      #expect(count == 14)
    }
  }
}
