import Foundation
import Testing
@testable import MisakiSwift

/// The BART alphabet contains no digits. A group that needed its fallback
/// therefore lost its figures too (`Qwen3.8` was US `kwˈɛnz`, GB `kwɛnkˈɛk`;
/// `fp16` was US `ˈɛfsˈɛ`, GB `ˈɛfpˈQ` at 3617c2d).
struct FallbackFigureTests {
  @Test func anUnreadLetterRunDoesNotTakeItsFigureToFallback() {
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      for (glued, spaced) in [
        ("Qwen3.8", "Qwen 3.8"), ("qwen3.8", "qwen 3.8"),
        ("fp16", "fp 16"), ("int8", "int 8"),
        ("py3.11", "py 3.11"), ("macos14.4", "macos 14.4"),
        ("Qwen3.8fp16", "Qwen 3.8 fp 16")
      ] {
        #expect(processor.phonemize(text: glued).0 == processor.phonemize(text: spaced).0,
                "\(glued), British: \(british)")
      }
    }
  }

  @Test func anUnreadSuffixDoesNotTakeItsFigureOrSymbolToFallback() {
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      let actual = processor.phonemize(text: "It took %.4fs, then more.").0
      let figure = processor.phonemize(text: "4").0
      let suffix = processor.phonemize(text: "fs").0
      #expect(actual.contains(figure), "\(actual)")
      #expect(actual.contains(suffix), "\(actual)")
      #expect(actual.contains(processor.phonemize(text: "%").0), "\(actual)")
    }
  }

  @Test func alreadyReadableGroupsKeepTheirReadings() {
    let fixtures = [
      ("GPT-4 USB3.2 v0.5 python3.11 U-S- state-of-the-art",
       "ʤˌipˌitˈi fˈɔɹ jˌuˌɛsbˈi θɹˈi pYnt tˈu vˈi zˈɪɹO pYnt fˈIv pˈIθˌɑn θɹˈi pYnt wˈʌn wˈʌn jˌuˈɛs stˈAtʌvðiˈɑɹt",
       "ʤˌiːpˌiːtˈiː fˈɔː jˌuːˌɛsbˈiː θɹˈiː pYnt tˈuː vˈiː zˈɪəɹQ pYnt fˈIv pˈIθn θɹˈiː pYnt wˈʌn wˈʌn jˌuːˈɛs stˈAtɒvðiˈɑːt")
    ]
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      for (text, american, english) in fixtures {
        #expect(processor.phonemize(text: text).0 == (british ? english : american))
      }
    }
  }

  /// The repair is reached only after the existing group walk fails. The
  /// letters-only dotted-acronym fast path must not enter that cubic walk.
  @Test func aLongDottedWordKeepsItsFastPath() {
    let processor = EnglishG2P()
    let text = Array(repeating: "a", count: 400).joined(separator: ".")
    let start = ContinuousClock.now
    _ = processor.phonemize(text: text)
    #expect(start.duration(to: .now) < .seconds(5))
  }
}
