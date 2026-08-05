import NaturalLanguage

enum EnglishTagResolver {
  static func resolve(
    nameTypeOrLexicalClass hybridTag: NLTag?,
    lexicalClass lexicalTag: NLTag?
  ) -> NLTag? {
    if let hybridTag, hybridTag.isProperNoun {
      return hybridTag
    }
    return lexicalTag ?? hybridTag
  }
}
