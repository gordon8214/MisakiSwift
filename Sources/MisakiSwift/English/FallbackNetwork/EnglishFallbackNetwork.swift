import Foundation
import MLXUtilsLibrary

/// Grapheme-to-phoneme for words no lexicon knows.
///
/// The arithmetic lives in ``BARTNetwork`` and runs on Accelerate; this type
/// owns the vocabulary either side of it. `MLXUtilsLibrary` is still imported,
/// but only for `MToken` — nothing here evaluates an `MLXArray`, which is the
/// property that lets a caller phonemize while synthesizing in the background.
final class EnglishFallbackNetwork {
  static let unknownTokenId = 3

  private let configuration: BARTConfig
  private let model: BARTNetwork
  private let graphemeToToken: [Character: Int]
  private let tokenToPhoneme: [Int: Character]

  private let british: Bool

  init(british: Bool) {
    guard let configuration = EnglishFallbackNetwork.loadConfig(british: british) else {
      preconditionFailure("Missing or unreadable BART config for \(british ? "gb" : "us")")
    }
    guard let weightsURL = Bundle.module.url(
      forResource: "\(british ? "gb" : "us")_bart", withExtension: "safetensors"
    ) else {
      preconditionFailure("Missing BART weights for \(british ? "gb" : "us")")
    }
    self.configuration = configuration
    self.british = british
    do {
      self.model = try BARTNetwork(
        configuration: configuration, file: try SafetensorsFile(contentsOf: weightsURL)
      )
    } catch {
      // A bundled resource, so this is a broken build rather than a runtime
      // condition — the same outcome the force-unwrapped MLX loader had, with a
      // message that says which file and why.
      preconditionFailure("Unusable BART weights for \(british ? "gb" : "us"): \(error)")
    }

    var graphemeDict: [Character: Int] = [:]
    for (index, grapheme) in configuration.graphemeChars.enumerated() {
      graphemeDict[grapheme] = index
    }
    self.graphemeToToken = graphemeDict

    var phonemeDict: [Int: Character] = [:]
    for (index, phoneme) in configuration.phonemeChars.enumerated() {
      phonemeDict[index] = phoneme
    }
    self.tokenToPhoneme = phonemeDict
  }

  private func graphemesToTokens(_ graphemes: String) -> [Int] {
    var tokens: [Int] = [configuration.bosTokenId]

    for char in graphemes {
      if let tokenId = graphemeToToken[char] {
        tokens.append(Int(tokenId))
      } else {
        tokens.append(EnglishFallbackNetwork.unknownTokenId)
      }
    }

    tokens.append(configuration.eosTokenId)
    return tokens
  }

  private func tokensToPhonemes(_ tokens: [Int]) -> String {
    var phonemes = ""

    for token in tokens {
      if token > EnglishFallbackNetwork.unknownTokenId {
        if let phoneme = tokenToPhoneme[Int(token)] {
          phonemes += String(phoneme)
        }
      }
    }

    return phonemes
  }

  func callAsFunction(_ word: MToken) -> (phoneme: String, rating: Int) {
    let outputText = tokensToPhonemes(model.generate(inputTokens: graphemesToTokens(word.text)))
    return (outputText, 1)
  }

  private static func loadConfig(british: Bool) -> BARTConfig? {
    let fileName = "\(british ? "gb" : "us")_bart_config"

    guard let url = Bundle.module.url(forResource: fileName, withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let config = try? JSONDecoder().decode(BARTConfig.self, from: data) else {
      return nil
    }
    return config
  }
}
