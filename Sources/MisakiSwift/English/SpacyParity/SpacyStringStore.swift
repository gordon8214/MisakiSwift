enum SpacyStringStore {
  static func id(for string: String, reserved: [String: UInt64]) -> UInt64 {
    reserved[string] ?? murmurHash64A(string)
  }

  private static func murmurHash64A(_ string: String) -> UInt64 {
    let bytes = Array(string.utf8)
    let multiplier: UInt64 = 0xc6a4a7935bd1e995
    let shift: UInt64 = 47
    var hash = UInt64(1) ^ (UInt64(bytes.count) &* multiplier)
    var cursor = 0
    while cursor + 8 <= bytes.count {
      var value: UInt64 = 0
      for offset in 0..<8 {
        value |= UInt64(bytes[cursor + offset]) << UInt64(offset * 8)
      }
      value = value &* multiplier
      value ^= value >> shift
      value = value &* multiplier
      hash ^= value
      hash = hash &* multiplier
      cursor += 8
    }
    if cursor < bytes.count {
      for offset in 0..<(bytes.count - cursor) {
        hash ^= UInt64(bytes[cursor + offset]) << UInt64(offset * 8)
      }
      hash = hash &* multiplier
    }
    hash ^= hash >> shift
    hash = hash &* multiplier
    hash ^= hash >> shift
    return hash
  }
}
