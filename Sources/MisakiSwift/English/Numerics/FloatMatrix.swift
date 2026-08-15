import Accelerate
import Foundation

/// Row-major fp32 matrix. `values.count == rows * columns`.
///
/// The English frontend runs two small neural networks — the spaCy tok2vec
/// tagger on every chunk, and the BART grapheme-to-phoneme fallback on words no
/// lexicon knows. Both used to run on MLX, which meant Metal command buffers
/// queued behind every phonemization. That is survivable for a foreground
/// preview and not survivable for a caller synthesizing in the background,
/// where iOS revokes GPU access and a late completion handler aborts the
/// process out of reach of any `catch`.
///
/// Neither network is remotely big enough to need a GPU: the tagger is 96 wide
/// and 4 deep, the BART is `d_model` 128 with one encoder and one decoder
/// layer. Accelerate on the CPU runs both in well under a millisecond, so this
/// is the whole substrate they need.
struct FloatMatrix {
  let rows: Int
  let columns: Int
  var values: [Float]

  init(rows: Int, columns: Int, values: [Float]) {
    // Four vDSP calls below address memory bounded by `values.count` while
    // deriving their write lengths from `rows`/`columns`. Enforcing the
    // identity here is what makes them safe by construction rather than by
    // caller discipline spread across three files.
    precondition(
      rows >= 0 && columns >= 0 && values.count == rows * columns,
      "FloatMatrix shape mismatch: \(rows)x\(columns) with \(values.count) values"
    )
    self.rows = rows
    self.columns = columns
    self.values = values
  }

  static func zeros(rows: Int, columns: Int) -> FloatMatrix {
    FloatMatrix(rows: rows, columns: columns, values: [Float](repeating: 0, count: rows * columns))
  }

  /// Rows `range`, as a matrix of the same width.
  func rowRange(_ range: Range<Int>) -> FloatMatrix {
    FloatMatrix(
      rows: range.count,
      columns: columns,
      values: Array(values[(range.lowerBound * columns)..<(range.upperBound * columns)])
    )
  }

  /// Columns `range` of every row — the per-head slice of a packed projection.
  func columnRange(_ range: Range<Int>) -> FloatMatrix {
    guard range.lowerBound != 0 || range.count != columns else { return self }
    var sliced = [Float](repeating: 0, count: rows * range.count)
    for row in 0..<rows {
      let source = row * columns + range.lowerBound
      sliced.replaceSubrange(
        (row * range.count)..<((row + 1) * range.count),
        with: values[source..<(source + range.count)]
      )
    }
    return FloatMatrix(rows: rows, columns: range.count, values: sliced)
  }

  /// Each row as its own array.
  func rowArrays() -> [[Float]] {
    (0..<rows).map { Array(values[($0 * columns)..<(($0 + 1) * columns)]) }
  }
}

/// The dense-linear-algebra primitives both networks are built from.
enum MatrixMath {

  /// `output[t, n] = Σ_k lhs[t, k] * rhs[k, n]`
  static func multiply(_ lhs: FloatMatrix, _ rhs: FloatMatrix) -> FloatMatrix {
    precondition(lhs.columns == rhs.rows, "matmul shape mismatch")
    guard lhs.rows > 0, rhs.columns > 0, lhs.columns > 0 else {
      return FloatMatrix.zeros(rows: lhs.rows, columns: rhs.columns)
    }
    var output = [Float](repeating: 0, count: lhs.rows * rhs.columns)
    lhs.values.withUnsafeBufferPointer { a in
      rhs.values.withUnsafeBufferPointer { b in
        output.withUnsafeMutableBufferPointer { c in
          vDSP_mmul(
            a.baseAddress!, 1, b.baseAddress!, 1, c.baseAddress!, 1,
            vDSP_Length(lhs.rows), vDSP_Length(rhs.columns), vDSP_Length(lhs.columns)
          )
        }
      }
    }
    return FloatMatrix(rows: lhs.rows, columns: rhs.columns, values: output)
  }

  /// Adds `bias` to every row in place.
  static func addRowwise(_ matrix: inout FloatMatrix, _ bias: [Float]) {
    precondition(bias.count == matrix.columns, "bias shape mismatch")
    let columns = matrix.columns
    matrix.values.withUnsafeMutableBufferPointer { destination in
      bias.withUnsafeBufferPointer { source in
        for row in 0..<matrix.rows {
          vDSP_vadd(
            destination.baseAddress! + row * columns, 1,
            source.baseAddress!, 1,
            destination.baseAddress! + row * columns, 1,
            vDSP_Length(columns)
          )
        }
      }
    }
  }

  /// Element-wise `lhs += rhs`.
  static func add(_ lhs: inout FloatMatrix, _ rhs: FloatMatrix) {
    precondition(
      lhs.rows == rhs.rows && lhs.columns == rhs.columns, "residual shape mismatch"
    )
    lhs.values.withUnsafeMutableBufferPointer { destination in
      rhs.values.withUnsafeBufferPointer { source in
        vDSP_vadd(
          destination.baseAddress!, 1, source.baseAddress!, 1,
          destination.baseAddress!, 1, vDSP_Length(destination.count)
        )
      }
    }
  }

  /// Element-wise `matrix *= scalar`.
  static func scale(_ matrix: inout FloatMatrix, by scalar: Float) {
    var scalar = scalar
    matrix.values.withUnsafeMutableBufferPointer { buffer in
      vDSP_vsmul(
        buffer.baseAddress!, 1, &scalar, buffer.baseAddress!, 1, vDSP_Length(buffer.count)
      )
    }
  }

  /// `(x - mean) * rsqrt(variance + epsilon) * gain + bias`, per row.
  ///
  /// Population variance (÷ N), epsilon inside the root. `epsilon` differs by
  /// caller — thinc's tok2vec uses 1e-8, the BART layer norms 1e-5 — and
  /// getting it from the caller is what keeps one implementation serving both.
  /// Sums accumulate in `Double`; the inputs are fp32 either way, but a
  /// 96-wide fp32 accumulation sits needlessly close to the parity fixture's
  /// 1e-4 tolerance for no gain in speed at this size.
  static func layerNormalized(
    _ matrix: FloatMatrix, gain: [Float], bias: [Float], epsilon: Double
  ) -> FloatMatrix {
    precondition(
      gain.count == matrix.columns && bias.count == matrix.columns,
      "layer-norm shape mismatch"
    )
    let columns = matrix.columns
    var result = [Float](repeating: 0, count: matrix.values.count)
    for row in 0..<matrix.rows {
      let start = row * columns
      var sum = 0.0
      for column in 0..<columns { sum += Double(matrix.values[start + column]) }
      let mean = sum / Double(columns)
      var squares = 0.0
      for column in 0..<columns {
        let centered = Double(matrix.values[start + column]) - mean
        squares += centered * centered
      }
      let scale = Float(1.0 / (squares / Double(columns) + epsilon).squareRoot())
      let meanValue = Float(mean)
      for column in 0..<columns {
        result[start + column] =
          (matrix.values[start + column] - meanValue) * scale * gain[column] + bias[column]
      }
    }
    return FloatMatrix(rows: matrix.rows, columns: columns, values: result)
  }

  /// Softmax across each row, shifted by the row maximum for stability.
  static func softmaxRows(_ matrix: FloatMatrix) -> FloatMatrix {
    let columns = matrix.columns
    var result = matrix.values
    for row in 0..<matrix.rows {
      let start = row * columns
      var largest = -Float.greatestFiniteMagnitude
      for column in 0..<columns { largest = Swift.max(largest, result[start + column]) }
      var total: Float = 0
      for column in 0..<columns {
        let value = Foundation.exp(result[start + column] - largest)
        result[start + column] = value
        total += value
      }
      guard total > 0 else { continue }
      for column in 0..<columns { result[start + column] /= total }
    }
    return FloatMatrix(rows: matrix.rows, columns: columns, values: result)
  }

  /// Exact erf-based GELU, matching `"activation_function": "gelu"` in the BART
  /// config and MLXNN's `gelu` — *not* the tanh approximation, which differs by
  /// enough to change a greedy argmax on a near-tie.
  static func gelu(_ matrix: inout FloatMatrix) {
    let inverseSquareRootOfTwo: Float = 0.707_106_781_186_547_5
    for index in matrix.values.indices {
      let value = matrix.values[index]
      matrix.values[index] = value * 0.5 * (1 + erff(value * inverseSquareRootOfTwo))
    }
  }

  /// `[N, C]` → `[N, 3C]`, each row becoming `[previous, self, next]` with
  /// zeros beyond the ends.
  static func windowExpanded(_ matrix: FloatMatrix) -> FloatMatrix {
    let columns = matrix.columns
    var result = [Float](repeating: 0, count: matrix.rows * columns * 3)
    for row in 0..<matrix.rows {
      let destination = row * columns * 3
      if row > 0 {
        let previous = (row - 1) * columns
        result.replaceSubrange(
          destination..<(destination + columns),
          with: matrix.values[previous..<(previous + columns)]
        )
      }
      let current = row * columns
      result.replaceSubrange(
        (destination + columns)..<(destination + 2 * columns),
        with: matrix.values[current..<(current + columns)]
      )
      if row + 1 < matrix.rows {
        let next = (row + 1) * columns
        result.replaceSubrange(
          (destination + 2 * columns)..<(destination + 3 * columns),
          with: matrix.values[next..<(next + columns)]
        )
      }
    }
    return FloatMatrix(rows: matrix.rows, columns: columns * 3, values: result)
  }

  /// Zero rows above and below, so a window can reach past the real tokens.
  static func verticallyPadded(_ matrix: FloatMatrix, by padding: Int) -> FloatMatrix {
    guard padding > 0 else { return matrix }
    let blank = [Float](repeating: 0, count: padding * matrix.columns)
    return FloatMatrix(
      rows: matrix.rows + 2 * padding,
      columns: matrix.columns,
      values: blank + matrix.values + blank
    )
  }

  /// One embedding row per index.
  static func embeddingRows(table: [Float], width: Int, indexes: [Int]) -> FloatMatrix {
    var result = [Float](repeating: 0, count: indexes.count * width)
    for (row, index) in indexes.enumerated() {
      result.replaceSubrange(
        (row * width)..<((row + 1) * width), with: table[(index * width)..<((index + 1) * width)]
      )
    }
    return FloatMatrix(rows: indexes.count, columns: width, values: result)
  }

  /// Sums `keysPerRow` embedding rows per output row — the hash-embed gather.
  ///
  /// The only gather here that reads through a raw pointer, so unlike
  /// `embeddingRows` a bad index corrupts instead of trapping. The caller's
  /// guarantee (`table.shape == [feature.rows, width]` and indices taken
  /// modulo `feature.rows`) lives in another file, so it is restated here.
  static func summedEmbeddingRows(
    table: [Float], width: Int, indexes: [Int], keysPerRow: Int
  ) -> FloatMatrix {
    precondition(width > 0 && keysPerRow > 0, "embedding gather needs positive dimensions")
    precondition(
      table.count % width == 0, "embedding table is not a multiple of its width"
    )
    precondition(
      indexes.count % keysPerRow == 0, "ragged embedding index list"
    )
    let tableRows = table.count / width
    precondition(
      indexes.allSatisfy { $0 >= 0 && $0 < tableRows }, "embedding index out of range"
    )
    let rows = indexes.count / keysPerRow
    var result = [Float](repeating: 0, count: rows * width)
    result.withUnsafeMutableBufferPointer { destination in
      table.withUnsafeBufferPointer { source in
        for row in 0..<rows {
          let target = destination.baseAddress! + row * width
          for key in 0..<keysPerRow {
            vDSP_vadd(
              target, 1,
              source.baseAddress! + indexes[row * keysPerRow + key] * width, 1,
              target, 1, vDSP_Length(width)
            )
          }
        }
      }
    }
    return FloatMatrix(rows: rows, columns: width, values: result)
  }

  /// Side-by-side join: `[T, A]` and `[T, B]` → `[T, A + B]`.
  static func horizontallyConcatenated(_ lhs: FloatMatrix, _ rhs: FloatMatrix) -> FloatMatrix {
    // Above the early returns, not below: the zero-column accumulator both
    // callers seed with is exactly the case that would otherwise skip the
    // check and silently adopt the other operand's row count.
    precondition(lhs.rows == rhs.rows, "concat shape mismatch")
    guard lhs.columns > 0 else { return rhs }
    guard rhs.columns > 0 else { return lhs }
    let columns = lhs.columns + rhs.columns
    var result = [Float](repeating: 0, count: lhs.rows * columns)
    for row in 0..<lhs.rows {
      let destination = row * columns
      result.replaceSubrange(
        destination..<(destination + lhs.columns),
        with: lhs.values[(row * lhs.columns)..<((row + 1) * lhs.columns)]
      )
      result.replaceSubrange(
        (destination + lhs.columns)..<(destination + columns),
        with: rhs.values[(row * rhs.columns)..<((row + 1) * rhs.columns)]
      )
    }
    return FloatMatrix(rows: lhs.rows, columns: columns, values: result)
  }

  /// Index of the largest value in each row. Ties keep the lowest index, which
  /// is what `argMax` does in both MLX and NumPy.
  static func argmaxPerRow(_ matrix: FloatMatrix) -> [Int] {
    (0..<matrix.rows).map { row in
      let start = row * matrix.columns
      var best = 0
      for column in 1..<matrix.columns
      where matrix.values[start + column] > matrix.values[start + best] {
        best = column
      }
      return best
    }
  }

  /// `[rows, columns]` → `[columns, rows]`.
  ///
  /// `vDSP_mtrans` writes `rows * columns` floats unconditionally, so sizing
  /// the destination from `values.count` instead is an out-of-bounds write the
  /// moment the two disagree — and Accelerate is uninstrumented, so it corrupts
  /// silently rather than trapping. The precondition and the explicit count are
  /// what close that.
  static func transposed(_ values: [Float], rows: Int, columns: Int) -> FloatMatrix {
    precondition(rows >= 0 && columns >= 0, "negative matrix dimension")
    precondition(
      values.count == rows * columns,
      "transpose shape mismatch: \(rows)x\(columns) with \(values.count) values"
    )
    var result = [Float](repeating: 0, count: rows * columns)
    values.withUnsafeBufferPointer { source in
      result.withUnsafeMutableBufferPointer { destination in
        vDSP_mtrans(
          source.baseAddress!, 1, destination.baseAddress!, 1,
          vDSP_Length(columns), vDSP_Length(rows)
        )
      }
    }
    return FloatMatrix(rows: columns, columns: rows, values: result)
  }

  static func transposed(_ matrix: FloatMatrix) -> FloatMatrix {
    transposed(matrix.values, rows: matrix.rows, columns: matrix.columns)
  }
}

/// An affine projection `x · Wᵀ + b`, the convention every weight file here
/// stores (`[outputs, inputs]`). The transpose is paid once at load.
struct LinearLayer {
  let weight: FloatMatrix
  let bias: [Float]?

  init(weight: SafetensorsFile.Tensor, bias: SafetensorsFile.Tensor?) throws {
    guard weight.shape.count == 2 else {
      throw SpacyParityError.invalidResource("linear weight is not a matrix")
    }
    if let bias, bias.shape != [weight.shape[0]] {
      throw SpacyParityError.invalidResource("linear weight/bias shapes disagree")
    }
    self.weight = MatrixMath.transposed(
      weight.values, rows: weight.shape[0], columns: weight.shape[1]
    )
    self.bias = bias?.values
  }

  func callAsFunction(_ input: FloatMatrix) -> FloatMatrix {
    var projected = MatrixMath.multiply(input, weight)
    if let bias { MatrixMath.addRowwise(&projected, bias) }
    return projected
  }
}

/// Per-row scale and shift at a caller-supplied epsilon.
struct LayerNormLayer {
  let gain: [Float]
  let bias: [Float]
  let epsilon: Double

  init(gain: SafetensorsFile.Tensor, bias: SafetensorsFile.Tensor, epsilon: Double) throws {
    guard gain.shape.count == 1, gain.shape == bias.shape else {
      throw SpacyParityError.invalidResource("layer-norm shapes disagree")
    }
    self.gain = gain.values
    self.bias = bias.values
    self.epsilon = epsilon
  }

  func callAsFunction(_ input: FloatMatrix) -> FloatMatrix {
    MatrixMath.layerNormalized(input, gain: gain, bias: bias, epsilon: epsilon)
  }
}
