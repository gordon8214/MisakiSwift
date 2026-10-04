import Testing
@testable import MisakiSwift

struct OperatingSystemNameTests {
  /// Derived from the names' own correct readings at 3617c2d; tvOS has no
  /// correct reading, so its oracle is the existing spelled TVOS. Both
  /// dialects' compound stress is preserved, including every TV letter.
  @Test func aCapitalizedOSSuffixReadsAsLettersInEveryContext() {
    let names: [(String, String, String)] = [
      ("tvOS", "tˌivˌiˌOˈɛs", "tˌiːvˌiːˌQˈɛs"),
      ("TvOS", "tˌivˌiˌOˈɛs", "tˌiːvˌiːˌQˈɛs"),
      ("TVOS", "tˌivˌiˌOˈɛs", "tˌiːvˌiːˌQˈɛs"),
      ("visionOS", "vˌɪʒənˌOˈɛs", "vˌɪʒᵊnˌQˈɛs"),
      ("VisionOS", "vˌɪʒənˌOˈɛs", "vˌɪʒᵊnˌQˈɛs"),
      ("watchOS", "wˌɑʧˌOˈɛs", "wˌɒʧˌQˈɛs"),
      ("WatchOS", "wˌɑʧˌOˈɛs", "wˌɒʧˌQˈɛs"),
      ("ChromeOS", "kɹˌOmˌOˈɛs", "kɹˌQmˌQˈɛs"),
      ("webOS", "wˌɛbˌOˈɛs", "wˌɛbˌQˈɛs"),
      ("HarmonyOS", "hˌɑɹməniˌOˈɛs", "hˌɑːməniˌQˈɛs"),
      ("SteamOS", "stˌimˌOˈɛs", "stˌiːmˌQˈɛs")
    ]
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      for (name, american, english) in names {
        let expected = british ? english : american
        for tail in ["27", "twenty-seven", "eleven", "twenty", "is here", "well-known apps"] {
          #expect(processor.phonemize(text: "\(name) \(tail)").0.hasPrefix(expected + " "), "\(name) \(tail)")
        }
        let plural = expected + (british ? "ɪz" : "ᵻz")
        #expect(processor.phonemize(text: "\(name)'s update").0.hasPrefix(plural + " "))
        #expect(processor.phonemize(text: "\(name)es update").0.hasPrefix(plural + " "))
      }
    }
  }

  @Test func alreadyCorrectNamesKeepTheirOwnCompoundStress() {
    for british in [false, true] {
      let processor = EnglishG2P(british: british)
      for (name, american, english) in [
        ("macOS", "mˌækˌOˈɛs", "mˌakˌQˈɛs"),
        ("MacOS", "mˌækˌOˈɛs", "mˌakˌQˈɛs"),
        ("iPadOS", "ˌIpˈædˌOˈɛs", "ˌIpˈadˌQˈɛs"),
        ("IPadOS", "ˌIpˈædˌOˈɛs", "ˌIpˈadˌQˈɛs"),
        ("iOS", "ˌIOˈɛs", "IQˈɛs"),
        ("OS", "ˌOˈɛs", "ˌQˈɛs"),
        ("Wear OS", "wˈɛɹ ˌOˈɛs", "wˈɛː ˌQˈɛs")
      ] {
        let expected = british ? english : american
        #expect(processor.phonemize(text: "\(name) is here").0.hasPrefix(expected + " "))
        #expect(processor.phonemize(text: "\(name) twenty-seven").0.hasPrefix(expected + " "))
      }
      for word in ["CHAOS", "PATHOS"] {
        #expect(processor.phonemize(text: word).0 == processor.phonemize(text: word.lowercased()).0)
      }
    }
  }
}
