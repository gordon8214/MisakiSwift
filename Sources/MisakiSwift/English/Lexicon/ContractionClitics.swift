import Foundation

/// How the lexicon reads a contraction it does not list whole: the host, then
/// the clitic as the lexicon's own contractions read it after a sound of that
/// kind.
///
/// Neither lexicon has an entry for `'ve` or `'re`, and the British one has
/// none for `'ll` either. spaCy splits "should've" into "should" + "'ve", so the
/// grouped word missed as a whole and its clitic missed alone, and Misaki sent
/// the whole word to the BART fallback, which reads a spelling: `ʃˈOld`
/// ("shoald"), `wˈʊldv`, `mˈAv`. `'re` did worse, because `subtokenize` splits
/// the apostrophe off and "re" IS a gold word (the musical note, `ɹˌA`), so
/// every "who're", "what're" and "there're" ended "-ray". In all caps spaCy does
/// not split a contraction at all, and one whose lowercase is not a whole gold
/// entry was spelled letter by letter.
///
/// No phoneme string here is authored. Every reading is the difference between
/// two entries the lexicon already holds, derived when the lexicon loads: the
/// suffix a listed contraction adds to its host. A missing or reshaped entry
/// leaves that reading nil, and the contraction falls through exactly as before.
struct ContractionClitics {

  /// `'ve` after a vowel, from `we've` over `we`: `v`.
  let fusedHave: String?
  /// `'ve` after a consonant or a modal, from `could've` over `could`: `əv`.
  let syllabicHave: String?
  /// `'re` after anything. Its three listed forms (`they're`, `we're`,
  /// `you're`) are smoothed into the pronoun's vowel, so none of them yields
  /// the clitic as a suffix. The clitic is the unstressed rhotic syllable,
  /// which the lexicon spells alike wherever a suffix adds one to a vowel-final
  /// stem (`doer`, `freer`, `newer`, `higher`): American `əɹ`, British `ə`.
  let syllabicAre: String?
  /// `'ll` where the lexicon lists the clitic itself (American `əl`). It is
  /// used verbatim so that every reading the grouped word already produced
  /// stays byte-identical.
  let listedWill: String?
  /// `'ll` after a vowel where no clitic is listed, from `he'll` over `he`.
  let fusedWill: String?
  /// `'ll` after a consonant where no clitic is listed, from `it'll` over `it`.
  let syllabicWill: String?
  /// `'d` as listed (`d`), which is what the grouped word always appended.
  let listedWould: String?
  /// `'d` after `t` or `d`, from `it'd` over `it`: `əd`. The listed `d` there
  /// fused into the stop ("that'd" read `ðˈætd`); `pastEd` inserts a vowel
  /// between an alveolar stop and a `d` suffix for the same reason.
  let syllabicWould: String?
  /// `n't` after an r-spelled host, from `aren't` over `are`: `nt`.
  let rhoticNot: String?
  /// `n't` elsewhere, from `didn't` over `did`: `ᵊnt`.
  let syllabicNot: String?
  /// What joins an r-spelled host to a vowel-initial clitic, from `where'er`
  /// over `where` and `e'er`: British `ɹ` (the linking r it also writes in
  /// `therein` and `thereof`), American nothing, since its host keeps its `ɹ`.
  let linking: String?
  /// Hosts the lexicon lists a negative contraction for (`mayn't`,
  /// `mightn't`, …), which are exactly the auxiliaries. A modal keeps `'ve`
  /// syllabic whatever its final sound: gold `could've`, `might've` and
  /// British `may've` are all `əv`, while every pronoun's is fused (`I've`,
  /// `we've`, `they've`, `you've`).
  let auxiliaries: Set<String>

  init(golds: [String: Any]) {
    func reading(_ key: String) -> String? {
      let value = golds[key]
      if let string = value as? String { return string }
      if let variants = value as? [String: String?], let fallback = variants["DEFAULT"] { return fallback }
      return nil
    }
    func suffix(_ whole: String, over host: String) -> String? {
      guard let whole = reading(whole), let host = reading(host) else { return nil }
      return ContractionClitics.suffix(of: whole, over: host)
    }

    fusedHave = suffix("we've", over: "we")
    syllabicHave = suffix("could've", over: "could")
    syllabicAre = suffix("doer", over: "do")
    listedWill = reading("'ll")
    fusedWill = suffix("he'll", over: "he")
    syllabicWill = suffix("it'll", over: "it")
    listedWould = reading("'d")
    syllabicWould = suffix("it'd", over: "it")
    rhoticNot = suffix("aren't", over: "are")
    syllabicNot = suffix("didn't", over: "did")
    if let joined = suffix("where'er", over: "where"), let ever = reading("e'er").map(Self.unstressed),
       joined.hasSuffix(ever) {
      linking = String(joined.dropLast(ever.count))
    } else {
      linking = nil
    }
    auxiliaries = Set(golds.keys.lazy.filter { $0.hasSuffix("n't") && $0 == $0.lowercased() }.map { String($0.dropLast(3)) })
  }

  /// What `whole` adds after `host`, both read without stress marks. An
  /// American host's final `t` may be flapped in the whole form (`might` is
  /// `mˌIt`, `might've` is `mˈIɾəv`), which still counts as the same host.
  static func suffix(of whole: String, over host: String) -> String? {
    let whole = unstressed(whole)
    let host = unstressed(host)
    if whole.hasPrefix(host) { return String(whole.dropFirst(host.count)) }
    if host.hasSuffix("t"), whole.hasPrefix(host.dropLast() + "ɾ") { return String(whole.dropFirst(host.count)) }
    return nil
  }

  static func unstressed(_ phonemes: String) -> String {
    phonemes.filter { $0 != Lexicon.primaryStress && $0 != Lexicon.secondaryStress }
  }

  /// A contraction's host and its lowercase clitic: `n't`, or the text after
  /// the LAST apostrophe, so "he'd've" is "he'd" + `ve`. `'s` belongs to
  /// `stem_s` and `'m` has no host but "I", which gold lists whole.
  static func split(_ word: String) -> (host: String, clitic: String)? {
    let lower = word.lowercased()
    if lower.hasSuffix("n't") {
      let host = String(word.dropLast(3))
      return host.last?.isLetter == true ? (host, "n't") : nil
    }
    guard let apostrophe = word.lastIndex(of: "'") else { return nil }
    let host = String(word[..<apostrophe])
    let clitic = word[word.index(after: apostrophe)...].lowercased()
    guard host.last?.isLetter == true, ["ve", "re", "ll", "d"].contains(clitic) else { return nil }
    return (host, clitic)
  }

  /// The whole contraction: `phonemes`, the reading of a host spelled `host`,
  /// joined to `clitic`. Nil where the lexicon supplied nothing to derive the
  /// clitic from.
  func reading(of clitic: String, afterHost host: String, phonemes: String, british: Bool) -> String? {
    guard let final = phonemes.last else { return nil }
    let lowerHost = host.lowercased()
    let endsInVowel = Lexicon.vowelSet.contains(final) || final == "ː"
    let rhotic = lowerHost.hasSuffix("r") || lowerHost.hasSuffix("re")
    let suffix: String?
    var listed = false
    switch clitic {
    case "ve":
      suffix = endsInVowel && !auxiliaries.contains(lowerHost) ? fusedHave : syllabicHave
    case "re":
      suffix = syllabicAre
    case "ll":
      listed = listedWill != nil
      suffix = listedWill ?? (endsInVowel ? fusedWill : syllabicWill)
    case "d":
      listed = final != "t" && final != "d"
      suffix = listed ? listedWould : syllabicWould
    case "n't":
      suffix = rhotic ? rhoticNot : syllabicNot
    default:
      return nil
    }
    guard let suffix, let opening = suffix.first else { return nil }
    // A schwa-final host supplies the clitic's schwa: "NASA'll" is `nˈæsəl`.
    // The lexicon writes two schwas in a row only across a hyphen
    // (`kala-azar`, `meta-analysis`), and a clitic is not a second word.
    if final == "ə", opening == "ə" { return phonemes + suffix.dropFirst() }
    // A listed clitic is appended exactly as the grouped word appended it, so
    // every contraction that already read correctly reads byte-identically.
    guard !listed, Lexicon.vowelSet.contains(opening) else { return phonemes + suffix }
    if rhotic, endsInVowel {
      guard let linking else { return nil }
      return phonemes + linking + suffix
    }
    return Self.flapped(phonemes, british: british) + suffix
  }

  /// The American flap before a vowel-initial clitic, by the same rule
  /// `pastEd` and `progIng` apply to `-ed` and `-ing`: a final `t` after one
  /// of `Lexicon.usTaus` (`it'd` is `ˈɪɾəd`, `might've` `mˈIɾəv`).
  static func flapped(_ phonemes: String, british: Bool) -> String {
    guard !british, phonemes.hasSuffix("t"), let penult = phonemes.dropLast().last,
          Lexicon.usTaus.contains(penult) else { return phonemes }
    return String(phonemes.dropLast()) + "ɾ"
  }
}
