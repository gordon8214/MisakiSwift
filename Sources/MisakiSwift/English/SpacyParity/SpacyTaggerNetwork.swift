import Foundation

/// The one layer type the spaCy tok2vec encoder needs that the BART fallback
/// does not: a linear projection to `outputs * pieces` followed by a max over
/// the pieces. Everything else it is built from — matmul, layer norm, the
/// hash-embed gather — is shared, in `Numerics/FloatMatrix.swift`.
struct SpacyMaxoutLayer {
  /// `[inputs, outputs * pieces]` — transposed once at load.
  let weight: FloatMatrix
  let bias: [Float]
  let outputs: Int
  let pieces: Int

  /// - Parameters:
  ///   - weight: the file's `[outputs, pieces, inputs]` tensor.
  ///   - bias: the file's `[outputs, pieces]` tensor.
  init(weight: SafetensorsFile.Tensor, bias: SafetensorsFile.Tensor) throws {
    guard weight.shape.count == 3, bias.shape.count == 2,
          bias.shape[0] == weight.shape[0], bias.shape[1] == weight.shape[1] else {
      throw SpacyParityError.invalidResource("spacy_tagger (maxout weight/bias shapes disagree)")
    }
    self.outputs = weight.shape[0]
    self.pieces = weight.shape[1]
    let inputs = weight.shape[2]
    self.weight = MatrixMath.transposed(weight.values, rows: outputs * pieces, columns: inputs)
    self.bias = bias.values
  }

  func callAsFunction(_ input: FloatMatrix) -> FloatMatrix {
    var projected = MatrixMath.multiply(input, weight)
    MatrixMath.addRowwise(&projected, bias)
    return Self.maxOverPieces(projected, outputs: outputs, pieces: pieces)
  }

  /// Collapses `[T, outputs * pieces]` to `[T, outputs]` by taking the largest
  /// piece. The flattened layout is `[output][piece]`, matching the
  /// `[outputs, pieces, inputs]` weight the file stores.
  static func maxOverPieces(_ matrix: FloatMatrix, outputs: Int, pieces: Int) -> FloatMatrix {
    precondition(matrix.columns == outputs * pieces, "maxout shape mismatch")
    var result = [Float](repeating: 0, count: matrix.rows * outputs)
    for row in 0..<matrix.rows {
      let source = row * matrix.columns
      let destination = row * outputs
      for output in 0..<outputs {
        var best = matrix.values[source + output * pieces]
        for piece in 1..<pieces {
          best = Swift.max(best, matrix.values[source + output * pieces + piece])
        }
        result[destination + output] = best
      }
    }
    return FloatMatrix(rows: matrix.rows, columns: outputs, values: result)
  }
}
