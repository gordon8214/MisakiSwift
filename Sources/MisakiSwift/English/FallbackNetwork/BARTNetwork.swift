import Foundation

/// The grapheme-to-phoneme BART, on Accelerate rather than MLX.
///
/// A faithful port of the MLX implementation it replaces, not a reimplementation
/// from the reference BART. Two of its quirks are load-bearing and must not be
/// "corrected", because the lexicon fixtures and the deployed server parity were
/// both recorded against exactly this arithmetic:
///
///   * **No causal mask.** `generate` decodes the whole prefix with no
///     self-attention mask, so every decoder position attends to every other
///     one, not just the ones before it. A textbook BART masks here. Adding the
///     mask changes the phonemes this model emits.
///   * **Layer norm after the residual.** `x = norm(x + sublayer(x))`, the
///     post-norm arrangement, matching the weights as they were exported.
///
/// The model is small — `d_model` 128, one encoder layer, one decoder layer,
/// one attention head, 63 tokens of vocabulary — and it only runs for a word no
/// lexicon knows, so a plain uncached greedy decode is more than fast enough.
struct BARTNetwork {

  /// Multi-head attention. The shipped configs use a single head, but the head
  /// split is implemented properly rather than assumed away: a config with more
  /// heads would otherwise produce confidently wrong phonemes instead of an
  /// error.
  struct Attention {
    let query: LinearLayer
    let key: LinearLayer
    let value: LinearLayer
    let output: LinearLayer
    let heads: Int
    let headDimension: Int

    init(prefix: String, file: SafetensorsFile, model: Int, heads: Int) throws {
      guard model % heads == 0 else {
        throw SpacyParityError.invalidResource("bart (d_model \(model) is not divisible by \(heads) heads)")
      }
      self.heads = heads
      self.headDimension = model / heads
      func projection(_ name: String) throws -> LinearLayer {
        try LinearLayer(
          weight: file.required("\(prefix).\(name).weight"),
          bias: file.tensors["\(prefix).\(name).bias"]
        )
      }
      self.query = try projection("q_proj")
      self.key = try projection("k_proj")
      self.value = try projection("v_proj")
      self.output = try projection("out_proj")
    }

    /// `keyValue` is the encoder output for cross-attention, and `queries`
    /// itself for self-attention.
    func callAsFunction(_ queries: FloatMatrix, keyValue: FloatMatrix? = nil) -> FloatMatrix {
      let source = keyValue ?? queries
      let projectedQueries = query(queries)
      let projectedKeys = key(source)
      let projectedValues = value(source)
      let scale = Float(1.0 / Double(headDimension).squareRoot())

      var combined = FloatMatrix(rows: queries.rows, columns: 0, values: [])
      for head in 0..<heads {
        let span = (head * headDimension)..<((head + 1) * headDimension)
        var scores = MatrixMath.multiply(
          projectedQueries.columnRange(span),
          MatrixMath.transposed(projectedKeys.columnRange(span))
        )
        MatrixMath.scale(&scores, by: scale)
        let attended = MatrixMath.multiply(
          MatrixMath.softmaxRows(scores), projectedValues.columnRange(span)
        )
        combined = MatrixMath.horizontallyConcatenated(combined, attended)
      }
      return output(combined)
    }
  }

  /// Two projections with a GELU between them.
  struct FeedForwardBlock {
    let inner: LinearLayer
    let outer: LinearLayer

    init(prefix: String, file: SafetensorsFile) throws {
      self.inner = try LinearLayer(
        weight: file.required("\(prefix).fc1.weight"), bias: file.tensors["\(prefix).fc1.bias"]
      )
      self.outer = try LinearLayer(
        weight: file.required("\(prefix).fc2.weight"), bias: file.tensors["\(prefix).fc2.bias"]
      )
    }

    func callAsFunction(_ input: FloatMatrix) -> FloatMatrix {
      var hidden = inner(input)
      MatrixMath.gelu(&hidden)
      return outer(hidden)
    }
  }

  struct EncoderLayer {
    let selfAttention: Attention
    let selfAttentionNorm: LayerNormLayer
    let feedForward: FeedForwardBlock
    let feedForwardNorm: LayerNormLayer

    init(prefix: String, file: SafetensorsFile, model: Int, heads: Int) throws {
      selfAttention = try Attention(
        prefix: "\(prefix).self_attn", file: file, model: model, heads: heads
      )
      selfAttentionNorm = try file.layerNorm("\(prefix).self_attn_layer_norm")
      feedForward = try FeedForwardBlock(prefix: prefix, file: file)
      feedForwardNorm = try file.layerNorm("\(prefix).final_layer_norm")
    }

    func callAsFunction(_ input: FloatMatrix) -> FloatMatrix {
      var hidden = input
      MatrixMath.add(&hidden, selfAttention(input))
      var normalized = selfAttentionNorm(hidden)
      let projected = feedForward(normalized)
      MatrixMath.add(&normalized, projected)
      return feedForwardNorm(normalized)
    }
  }

  struct DecoderLayer {
    let selfAttention: Attention
    let selfAttentionNorm: LayerNormLayer
    let crossAttention: Attention
    let crossAttentionNorm: LayerNormLayer
    let feedForward: FeedForwardBlock
    let feedForwardNorm: LayerNormLayer

    init(prefix: String, file: SafetensorsFile, model: Int, heads: Int) throws {
      selfAttention = try Attention(
        prefix: "\(prefix).self_attn", file: file, model: model, heads: heads
      )
      selfAttentionNorm = try file.layerNorm("\(prefix).self_attn_layer_norm")
      crossAttention = try Attention(
        prefix: "\(prefix).encoder_attn", file: file, model: model, heads: heads
      )
      crossAttentionNorm = try file.layerNorm("\(prefix).encoder_attn_layer_norm")
      feedForward = try FeedForwardBlock(prefix: prefix, file: file)
      feedForwardNorm = try file.layerNorm("\(prefix).final_layer_norm")
    }

    func callAsFunction(_ input: FloatMatrix, encoderOutput: FloatMatrix) -> FloatMatrix {
      var hidden = input
      MatrixMath.add(&hidden, selfAttention(input))
      var normalized = selfAttentionNorm(hidden)

      var crossed = normalized
      MatrixMath.add(&crossed, crossAttention(normalized, keyValue: encoderOutput))
      normalized = crossAttentionNorm(crossed)

      var forwarded = normalized
      MatrixMath.add(&forwarded, feedForward(normalized))
      return feedForwardNorm(forwarded)
    }
  }

  /// BART offsets learned positions past the two reserved slots.
  private static let positionOffset = 2

  private let tokenEmbedding: [Float]
  private let encoderPositions: [Float]
  private let decoderPositions: [Float]
  private let encoderNorm: LayerNormLayer
  private let decoderNorm: LayerNormLayer
  private let encoderLayers: [EncoderLayer]
  private let decoderLayers: [DecoderLayer]
  /// Tied to `model.shared.weight`, transposed once.
  private let languageModelHead: FloatMatrix
  private let logitBias: [Float]
  private let model: Int
  private let vocabulary: Int

  let bosTokenId: Int
  let eosTokenId: Int

  init(configuration: BARTConfig, file: SafetensorsFile) throws {
    guard !configuration.scaleEmbedding else {
      // The shipped configs set this false and the MLX implementation ignored
      // it outright. Refusing is better than silently dropping a √d_model that
      // a future export might rely on.
      throw SpacyParityError.invalidResource("bart (scale_embedding is not supported)")
    }
    model = configuration.dModel
    vocabulary = configuration.vocabSize
    bosTokenId = configuration.bosTokenId
    eosTokenId = configuration.eosTokenId

    let shared = try file.required("model.shared.weight")
    guard shared.shape == [vocabulary, model] else {
      throw SpacyParityError.invalidResource("bart (model.shared.weight is \(shared.shape))")
    }
    tokenEmbedding = shared.values
    languageModelHead = MatrixMath.transposed(shared.values, rows: vocabulary, columns: model)

    encoderPositions = try file.required("model.encoder.embed_positions.weight").values
    decoderPositions = try file.required("model.decoder.embed_positions.weight").values
    encoderNorm = try file.layerNorm("model.encoder.layernorm_embedding")
    decoderNorm = try file.layerNorm("model.decoder.layernorm_embedding")

    // Locals, not `self.model` — a closure may not read a stored property
    // while the rest are still uninitialized.
    let width = configuration.dModel
    encoderLayers = try (0..<configuration.encoderLayers).map { index in
      try EncoderLayer(
        prefix: "model.encoder.layers.\(index)", file: file,
        model: width, heads: configuration.encoderAttentionHeads
      )
    }
    decoderLayers = try (0..<configuration.decoderLayers).map { index in
      try DecoderLayer(
        prefix: "model.decoder.layers.\(index)", file: file,
        model: width, heads: configuration.decoderAttentionHeads
      )
    }

    let bias = try file.required("final_logits_bias")
    guard bias.values.count == vocabulary else {
      throw SpacyParityError.invalidResource("bart (final_logits_bias is \(bias.shape))")
    }
    logitBias = bias.values
  }

  /// Rows in a learned-position table, which is `max_position_embeddings` plus
  /// the two reserved slots the offset skips.
  private func positionCount(_ table: [Float]) -> Int { table.count / model }

  private func embedded(_ tokens: [Int], positions: [Float]) -> FloatMatrix {
    var hidden = MatrixMath.embeddingRows(table: tokenEmbedding, width: model, indexes: tokens)
    let positionIndexes = (0..<tokens.count).map { $0 + Self.positionOffset }
    MatrixMath.add(
      &hidden, MatrixMath.embeddingRows(table: positions, width: model, indexes: positionIndexes)
    )
    return hidden
  }

  func encode(_ tokens: [Int]) -> FloatMatrix {
    // Positions are a direct table lookup, so an over-long token would read
    // past the end of it. Words arriving here are single lexicon misses and the
    // table holds 64 of them, but a pathological one (a URL-shaped token, say)
    // is reachable — and a truncated guess beats the out-of-bounds read the MLX
    // implementation would have taken.
    let limit = positionCount(encoderPositions) - Self.positionOffset
    let clamped = tokens.count <= limit
      ? tokens
      : Array(tokens.prefix(limit - 1)) + [eosTokenId]
    var hidden = encoderNorm(embedded(clamped, positions: encoderPositions))
    for layer in encoderLayers { hidden = layer(hidden) }
    return hidden
  }

  /// Logits for every position of `tokens`.
  func decode(_ tokens: [Int], encoderOutput: FloatMatrix) -> FloatMatrix {
    var hidden = decoderNorm(embedded(tokens, positions: decoderPositions))
    for layer in decoderLayers { hidden = layer(hidden, encoderOutput: encoderOutput) }
    var logits = MatrixMath.multiply(hidden, languageModelHead)
    MatrixMath.addRowwise(&logits, logitBias)
    return logits
  }

  /// Greedy decode. Returns the generated token ids, EOS excluded.
  ///
  /// `maxLength` and the terminal-EOS behaviour mirror the MLX original: the
  /// last iteration emits EOS rather than a token, and EOS is not appended when
  /// the model produces it on its own.
  func generate(inputTokens: [Int], maxLength: Int = 50) -> [Int] {
    let encoderOutput = encode(inputTokens)
    var decoded = [bosTokenId]
    var generated: [Int] = []

    for step in 0..<maxLength {
      if step == maxLength - 1 {
        generated.append(eosTokenId)
        break
      }
      let logits = decode(decoded, encoderOutput: encoderOutput)
      let next = MatrixMath.argmaxPerRow(logits.rowRange((logits.rows - 1)..<logits.rows))[0]
      if next == eosTokenId { break }
      generated.append(next)
      decoded.append(next)
      // Same bound as `encode`, on the growing prefix rather than the input.
      if decoded.count + Self.positionOffset >= positionCount(decoderPositions) { break }
    }
    return generated
  }
}

extension SafetensorsFile {
  func required(_ name: String) throws -> Tensor {
    guard let tensor = tensors[name] else {
      throw SpacyParityError.invalidResource("missing weight '\(name)'")
    }
    return tensor
  }

  /// The BART layer norms all use PyTorch's default epsilon, which is what
  /// MLXNN's `LayerNorm` defaulted to as well.
  func layerNorm(_ prefix: String, epsilon: Double = 1e-5) throws -> LayerNormLayer {
    try LayerNormLayer(
      gain: required("\(prefix).weight"), bias: required("\(prefix).bias"), epsilon: epsilon
    )
  }
}
