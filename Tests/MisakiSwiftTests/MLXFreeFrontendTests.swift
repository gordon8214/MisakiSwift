import Foundation
import Testing
import MLXUtilsLibrary
@testable import MisakiSwift

/// The English frontend must not evaluate MLX.
///
/// Both of its neural networks — the spaCy tok2vec tagger on every call, and
/// the BART grapheme-to-phoneme fallback on lexicon misses — used to run on
/// MLX, which queues Metal command buffers behind every phonemization. A caller
/// synthesizing in the background cannot survive that: iOS revokes GPU access
/// on `.background`, and a completion handler firing afterwards throws a C++
/// exception out of Metal's queue that no `catch` can reach, aborting the
/// process. That is the entire reason the on-device CoreML engine exists, so a
/// frontend it can share has to stay off MLX.
///
/// Both networks now run on Accelerate, and this is the guardrail. It is a
/// source scan rather than a runtime check because there is no API that reports
/// "an MLXArray was evaluated" — and the failure it guards against is not a
/// wrong answer but a crash on a device, hours into a background synthesis.
@Suite struct MLXFreeFrontendTests {

  /// `MLXUtilsLibrary` is deliberately allowed: it is imported only for
  /// `MToken`, a plain class. Linking MLX costs binary size; *evaluating* it is
  /// what the abort needs, and nothing here does.
  private static let allowedImports = ["MLXUtilsLibrary"]

  private var sourcesDirectory: URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()  // MisakiSwiftTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // package root
      .appending(path: "Sources/MisakiSwift")
  }

  @Test func noSourceFileImportsMLX() throws {
    let enumerator = try #require(
      FileManager.default.enumerator(at: sourcesDirectory, includingPropertiesForKeys: nil)
    )
    var scanned = 0
    var offenders: [String] = []

    for case let url as URL in enumerator where url.pathExtension == "swift" {
      scanned += 1
      let source = try String(contentsOf: url, encoding: .utf8)
      for line in source.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("import ") else { continue }
        let module = String(trimmed.dropFirst("import ".count))
          .trimmingCharacters(in: .whitespaces)
        guard module.hasPrefix("MLX"), !Self.allowedImports.contains(module) else { continue }
        offenders.append("\(url.lastPathComponent): \(module)")
      }
    }

    #expect(scanned > 20, "expected to scan the whole frontend, saw \(scanned) files")
    #expect(offenders.isEmpty, "MLX reached the frontend again: \(offenders.joined(separator: ", "))")
  }

  /// The two networks resolve without MLX being able to have run — construction
  /// is where the old implementations loaded their weights into `MLXArray`.
  @Test func bothNetworksBuildAndRun() throws {
    let tagger = try SpacyEnglishTagger()
    #expect(tagger.trace("The committee read the report.").pennTags.count == 6)

    let fallback = EnglishFallbackNetwork(british: false)
    let text = "zaymrastnes"
    let token = MToken(text: text, tokenRange: text.startIndex..<text.endIndex, whitespace: "")
    #expect(!fallback(token).phoneme.isEmpty)
  }
}
