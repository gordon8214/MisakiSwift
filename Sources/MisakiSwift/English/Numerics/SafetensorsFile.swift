import Foundation

/// Minimal reader for the fp32 subset of the safetensors format.
///
/// `MLX.loadArrays` was the only reason the spaCy tagger needed MLX to *load*
/// its weights, and the format is trivial enough that reading it directly costs
/// less than the dependency: an 8-byte little-endian header length, that many
/// bytes of JSON describing `{dtype, shape, data_offsets}` per tensor, then one
/// raw buffer those byte offsets index into.
///
/// Deliberately narrow. Only `F32` is accepted, because that is what
/// `spacy_tagger.safetensors` contains and a silently-misread dtype would
/// surface as subtly wrong Penn tags rather than as an error. Anything else is
/// rejected by name. Values are little-endian, which matches every platform
/// this package supports.
struct SafetensorsFile {
  struct Tensor {
    let shape: [Int]
    let values: [Float]
  }

  let tensors: [String: Tensor]

  init(contentsOf url: URL) throws {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    let name = url.lastPathComponent
    let base = data.startIndex

    guard data.count >= 8 else {
      throw SpacyParityError.invalidResource("\(name) (shorter than its header length field)")
    }
    var headerLength: UInt64 = 0
    _ = withUnsafeMutableBytes(of: &headerLength) { destination in
      data[base..<(base + 8)].copyBytes(to: destination)
    }
    headerLength = UInt64(littleEndian: headerLength)

    // A corrupt length must not be able to address outside the file, and the
    // cast has to happen after that check on 32-bit-Int platforms.
    guard headerLength <= UInt64(data.count - 8) else {
      throw SpacyParityError.invalidResource("\(name) (header length exceeds the file)")
    }
    let headerEnd = 8 + Int(headerLength)
    guard let header = try JSONSerialization.jsonObject(
      with: data[(base + 8)..<(base + headerEnd)]
    ) as? [String: Any] else {
      throw SpacyParityError.invalidResource("\(name) (header is not a JSON object)")
    }

    var parsed: [String: Tensor] = [:]
    parsed.reserveCapacity(header.count)
    for (key, value) in header {
      // Free-form provenance the format allows alongside the tensors.
      if key == "__metadata__" { continue }
      guard let entry = value as? [String: Any],
            let dtype = entry["dtype"] as? String,
            let shape = entry["shape"] as? [Int],
            let offsets = entry["data_offsets"] as? [Int],
            offsets.count == 2 else {
        throw SpacyParityError.invalidResource("\(name) (malformed entry '\(key)')")
      }
      guard dtype == "F32" else {
        throw SpacyParityError.invalidResource("\(name) ('\(key)' is \(dtype), expected F32)")
      }

      let (start, end) = (offsets[0], offsets[1])
      let count = shape.reduce(1, *)
      guard start >= 0, start <= end, headerEnd + end <= data.count,
            end - start == count * MemoryLayout<Float>.size else {
        throw SpacyParityError.invalidResource("\(name) ('\(key)' has out-of-range offsets)")
      }

      var values = [Float](repeating: 0, count: count)
      let range = (base + headerEnd + start)..<(base + headerEnd + end)
      // memcpy through `copyBytes`, so an unaligned tensor offset is fine.
      _ = values.withUnsafeMutableBytes { destination in
        data[range].copyBytes(to: destination)
      }
      parsed[key] = Tensor(shape: shape, values: values)
    }
    self.tensors = parsed
  }
}
