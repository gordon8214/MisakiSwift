import NaturalLanguage
import Testing
@testable import MisakiSwift

@Test func lexicalClassReplacesANonNameHybridTag() {
  let resolved = EnglishTagResolver.resolve(
    nameTypeOrLexicalClass: .otherWord,
    lexicalClass: .verb
  )

  #expect(resolved == .verb)
}

@Test func hybridNameTypesRemainAuthoritative() {
  for nameTag in [NLTag.personalName, .organizationName, .placeName] {
    let resolved = EnglishTagResolver.resolve(
      nameTypeOrLexicalClass: nameTag,
      lexicalClass: .noun
    )

    #expect(resolved == nameTag)
  }
}

@Test func resolverFallsBackWhenOneSchemeHasNoTag() {
  #expect(EnglishTagResolver.resolve(
    nameTypeOrLexicalClass: nil,
    lexicalClass: .adjective
  ) == .adjective)
  #expect(EnglishTagResolver.resolve(
    nameTypeOrLexicalClass: .otherWord,
    lexicalClass: nil
  ) == .otherWord)
  #expect(EnglishTagResolver.resolve(
    nameTypeOrLexicalClass: nil,
    lexicalClass: nil
  ) == nil)
}
