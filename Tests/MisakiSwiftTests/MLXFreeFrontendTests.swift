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
    var sawFrontendEntryPoint = false
    var offenders: [String] = []

    for case let url as URL in enumerator where url.pathExtension == "swift" {
      scanned += 1
      if url.lastPathComponent == "EnglishG2P.swift" { sawFrontendEntryPoint = true }
      let source = try String(contentsOf: url, encoding: .utf8)
      for line in source.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Attributes and import kinds are stripped first: `@preconcurrency
        // import MLX`, `@testable import MLX` and `import struct MLX.MLXArray`
        // all reintroduce MLX, and all of them slip past a bare
        // `hasPrefix("import ")` test — which is exactly how someone would
        // spell it while working around this guard.
        var rest = Substring(trimmed)
        while rest.hasPrefix("@") {
          rest = rest.drop { !$0.isWhitespace }.drop { $0.isWhitespace }
        }
        guard rest.hasPrefix("import ") else { continue }
        rest = rest.dropFirst("import ".count).drop { $0.isWhitespace }
        for kind in ["struct ", "class ", "enum ", "func ", "typealias ", "var ", "let ", "protocol "]
        where rest.hasPrefix(kind) {
          rest = rest.dropFirst(kind.count).drop { $0.isWhitespace }
        }
        // `import struct MLX.MLXArray` names the module before the first dot.
        let module = String(rest.prefix { !$0.isWhitespace }).split(separator: ".").first.map(String.init) ?? ""

        guard module.hasPrefix("MLX"), !Self.allowedImports.contains(module) else { continue }
        offenders.append("\(url.lastPathComponent): \(module)")
      }
    }

    // A count assertion alone sits on the boundary — this very change deleted
    // six files and added three — so pin a file that must always be scanned.
    #expect(scanned >= 10, "expected to scan the whole frontend, saw \(scanned) files")
    #expect(sawFrontendEntryPoint, "EnglishG2P.swift was not scanned; is the path still right?")
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
