import Testing
@testable import MisakiSwift

struct MarkupLabelTests {
  /// At 3617c2d the first '[' became the label's start and swallowed "at".
  @Test func anEditorialBracketDoesNotBecomeAForcedLabelsStart() {
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      let bracketed = processor.phonemize(text: "We [at [Verizon](/vəɹˈIzᵊn/)] believe.").0
      #expect(bracketed == processor.phonemize(text: "We at [Verizon](/vəɹˈIzᵊn/) believe.").0)
      #expect(processor.phonemize(text: "The carrier [which [Verizon](/vəɹˈIzᵊn/) bought] said so.").0
                == processor.phonemize(text: "The carrier which [Verizon](/vəɹˈIzᵊn/) bought said so.").0)
    }
  }

  @Test func validLabelsAndFeatureFlagsRemainRecognized() {
    let processor = EnglishG2P()
    for count in [1, 64, 65, 100] {
      let label = String(repeating: "a", count: count)
      #expect(processor.phonemize(text: "[\(label)](/fˈIv/)").0 == "fˈIv")
    }
    #expect(processor.phonemize(text: "[Ms.](/mˈɪz./)").0 == "mˈɪz.")
    #expect(processor.phonemize(text: "[El Niño](/ɛl nˈinjO/)").0 == "ɛl nˈinjO")
    #expect(processor.phonemize(text: "[five](0)").0 == "fˌIv")
    #expect(processor.phonemize(text: "[five](#a#)").1.contains { $0.`_`.num_flags == "a" })
    let longPhonemes = String(repeating: "f", count: 500)
    #expect(processor.phonemize(text: "[word](/\(longPhonemes)/)").0 == longPhonemes)
  }

  @Test func oversizedOrMultilineLabelsCannotForceAReading() {
    let processor = EnglishG2P()
    for label in [String(repeating: "a", count: 101), String(repeating: "😀", count: 51), "one\ntwo", "one\rtwo", "one\r\ntwo"] {
      let input = "[\(label)](/fˈIv/)"
      #expect(!processor.phonemize(text: input).1.contains { $0.`_`.rating == 5 }, "\(label.debugDescription)")
      #expect(processor.phonemize(text: input).0 == processor.phonemize(text: input, performPreprocess: false).0)
    }
  }
}
