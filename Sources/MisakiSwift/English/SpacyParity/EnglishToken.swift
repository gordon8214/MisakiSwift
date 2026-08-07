import Foundation
import NaturalLanguage

typealias PennTagMap = [ObjectIdentifier: String]

struct EnglishPOSTag {
  let lexicalClass: NLTag?
  let penn: String?

  static let none = EnglishPOSTag(lexicalClass: nil, penn: nil)

  init(lexicalClass: NLTag?, penn: String?) {
    self.lexicalClass = lexicalClass
    self.penn = penn
  }

  func resolvedPenn(for token: String?) -> String? {
    if let penn {
      return penn
    }
    return lexicalClass.map { pennTag(for: $0, token: token) }
  }

  var isProperNoun: Bool {
    if penn == "NNP" || penn == "NNPS" {
      return true
    }
    return lexicalClass?.isProperNoun ?? false
  }
}
