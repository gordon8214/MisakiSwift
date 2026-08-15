import Foundation
import Testing
@testable import MisakiSwift

/// The happy path is covered end-to-end and far more strictly by
/// `SpacyFrontendParityTests`, which reads the real 6.3 MB tagger weights and
/// checks the resulting vectors against deployed spaCy at 1e-4. What that can
/// never reach is the rejection behaviour — and a reader that accepted a
/// truncated header or silently misread a dtype would surface as subtly wrong
/// Penn tags, which is the hardest possible failure to trace back here.
@Suite struct SafetensorsFileTests {

  private func write(header: [String: Any], data: [Float]) throws -> URL {
    let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
    var bytes = Data()
    withUnsafeBytes(of: UInt64(headerData.count).littleEndian) { bytes.append(contentsOf: $0) }
    bytes.append(headerData)
    data.withUnsafeBufferPointer { bytes.append(Data(buffer: $0)) }
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("safetensors-\(UUID().uuidString).safetensors")
    try bytes.write(to: url)
    return url
  }

  private func entry(dtype: String = "F32", shape: [Int], start: Int, end: Int) -> [String: Any] {
    ["dtype": dtype, "shape": shape, "data_offsets": [start, end]]
  }

  @Test func readsShapeAndValuesInRowMajorOrder() throws {
    let url = try write(
      header: ["w": entry(shape: [2, 3], start: 0, end: 24)],
      data: [1, 2, 3, 4, 5, 6]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let file = try SafetensorsFile(contentsOf: url)
    #expect(file.tensors["w"]?.shape == [2, 3])
    #expect(file.tensors["w"]?.values == [1, 2, 3, 4, 5, 6])
  }

  @Test func readsSeveralTensorsFromOneBuffer() throws {
    let url = try write(
      header: [
        "a": entry(shape: [2], start: 0, end: 8),
        "b": entry(shape: [1], start: 8, end: 12)
      ],
      data: [1, 2, 3]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let file = try SafetensorsFile(contentsOf: url)
    #expect(file.tensors["a"]?.values == [1, 2])
    #expect(file.tensors["b"]?.values == [3])
  }

  /// Provenance the format permits alongside the tensors, and which has no
  /// `dtype` — reading it as one would fail the whole load.
  @Test func metadataIsSkippedRatherThanParsedAsATensor() throws {
    let url = try write(
      header: [
        "__metadata__": ["format": "pt"],
        "w": entry(shape: [1], start: 0, end: 4)
      ],
      data: [42]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let file = try SafetensorsFile(contentsOf: url)
    #expect(file.tensors.count == 1)
    #expect(file.tensors["w"]?.values == [42])
  }

  /// Only F32 is accepted. A quantized tensor read as float would decode to
  /// plausible-looking garbage rather than to an error.
  @Test func anUnsupportedDtypeIsRejected() throws {
    let url = try write(
      header: ["w": entry(dtype: "F16", shape: [2], start: 0, end: 4)],
      data: [1, 2]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: SpacyParityError.self) { _ = try SafetensorsFile(contentsOf: url) }
  }

  @Test func offsetsThatDisagreeWithTheShapeAreRejected() throws {
    let url = try write(
      header: ["w": entry(shape: [4], start: 0, end: 8)],
      data: [1, 2]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: SpacyParityError.self) { _ = try SafetensorsFile(contentsOf: url) }
  }

  @Test func offsetsPastTheEndOfTheFileAreRejected() throws {
    let url = try write(
      header: ["w": entry(shape: [8], start: 0, end: 32)],
      data: [1, 2]
    )
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: SpacyParityError.self) { _ = try SafetensorsFile(contentsOf: url) }
  }

  /// A header length larger than the file must not be used to address memory
  /// beyond it.
  @Test func aHeaderLengthLongerThanTheFileIsRejected() throws {
    var bytes = Data()
    withUnsafeBytes(of: UInt64(1 << 40).littleEndian) { bytes.append(contentsOf: $0) }
    bytes.append(Data([0x7b, 0x7d]))
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("safetensors-\(UUID().uuidString).safetensors")
    try bytes.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: SpacyParityError.self) { _ = try SafetensorsFile(contentsOf: url) }
  }

  @Test func aFileShorterThanItsLengthFieldIsRejected() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("safetensors-\(UUID().uuidString).safetensors")
    try Data([0, 1, 2]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: SpacyParityError.self) { _ = try SafetensorsFile(contentsOf: url) }
  }
}
