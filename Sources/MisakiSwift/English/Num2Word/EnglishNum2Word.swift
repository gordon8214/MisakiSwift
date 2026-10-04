import Foundation

/// Converts numbers to English words, converted from num2words Python package and from Num2Word_EN class
struct EnglishNum2Word {
  enum ConversionFormat {
    case ordinal
    case ordinalNum
    case decimal
    case year
  }
  
  private let negWord = "minus "
  private let pointWord = "point"
  private let excludeTitle = ["and", "point", "minus"]
  
  private let midNumWords: [(Int, String)] = [
    (1000, "thousand"), (100, "hundred"),
    (90, "ninety"), (80, "eighty"), (70, "seventy"),
    (60, "sixty"), (50, "fifty"), (40, "forty"),
    (30, "thirty"), (20, "twenty")
  ]
  
  private let lowNumWords = [
    "twenty", "nineteen", "eighteen", "seventeen",
    "sixteen", "fifteen", "fourteen", "thirteen",
    "twelve", "eleven", "ten", "nine", "eight",
    "seven", "six", "five", "four", "three", "two",
    "one", "zero"
  ]
  
  private let ords: [String: String] = [
    "one": "first", "two": "second", "three": "third",
    "four": "fourth", "five": "fifth", "six": "sixth",
    "seven": "seventh", "eight": "eighth", "nine": "ninth",
    "ten": "tenth", "eleven": "eleventh", "twelve": "twelfth"
  ]
  
  /// The powers of a thousand an `Int` holds, largest first: a quintillion
  /// down to a thousand.
  private let scales: [(Int, String)]

  init() {
    var scales: [(Int, String)] = [(1000, "thousand")]
    let highWords = ["m", "b", "tr", "quadr", "quint", "sext", "sept", "oct", "non", "dec"]
    for (index, word) in highWords.enumerated() {
      let power = 6 + (index * 3)
      let val = pow(10.0, Double(power))
      if val <= Double(Int.max) {
        scales.append((Int(val), word + "illion"))
      } else {
        // Currently really, really large numbers are not handled
      }
    }
    self.scales = scales.reversed()
  }
  
  private func merge(_ lPair: (String, Int), _ rPair: (String, Int)) -> (String, Int) {
    let (lText, lNum) = lPair
    let (rText, rNum) = rPair
    
    if lNum == 1 && rNum < 100 {
      return (rText, rNum)
    } else if 100 > lNum && lNum > rNum {
      return ("\(lText)-\(rText)", lNum + rNum)
    } else if lNum >= 100 && rNum < 100 {
      return ("\(lText) and \(rText)", lNum + rNum)
    } else if rNum > lNum {
      return ("\(lText) \(rText)", lNum * rNum)
    }
    return ("\(lText), \(rText)", lNum + rNum)
  }
  
  private func toOrdinal(_ decimalNumber: Decimal) -> String {
    let number = NSDecimalNumber(decimal: decimalNumber).intValue
    guard number > 0 else { return "" }
    
    var outWords = toCardinal(number).components(separatedBy: " ")
    var lastWords = outWords[outWords.count - 1].components(separatedBy: "-")
    var lastWord = lastWords[lastWords.count - 1].lowercased()
    
    if let ordinalWord = ords[lastWord] {
      lastWord = ordinalWord
    } else {
      if lastWord.hasSuffix("y") {
        lastWord = String(lastWord.dropLast()) + "ie"
      }
      lastWord += "th"
    }
    
    lastWords[lastWords.count - 1] = lastWord.capitalized
    outWords[outWords.count - 1] = lastWords.joined(separator: "-")
    return outWords.joined(separator: " ")
  }
  
  private func toOrdinalNum(_ decimalNumber: Decimal) -> String {
    let number = NSDecimalNumber(decimal: decimalNumber).intValue
    let ordinal = toOrdinal(decimalNumber)
    if ordinal.count >= 2 {
      let suffix = String(ordinal.suffix(2))
      return "\(number)\(suffix)"
    } else {
      return ""
    }
  }
  
  private func toCardinal(_ number: Int) -> String {
    if number < 0 {
      return negWord + toCardinal(abs(number))
    }
    
    if number < 21 {
      return lowNumWords[20 - number]
    }
    
    // Handle numbers from 21-99
    if number < 100 {
      let tens = (number / 10) * 10
      let ones = number % 10
      if ones == 0 {
        return midNumWords.first { $0.0 == tens }?.1 ?? ""
      } else {
        let tensWord = midNumWords.first { $0.0 == tens }?.1 ?? ""
        let onesWord = lowNumWords[20 - ones]
        return "\(tensWord)-\(onesWord)"
      }
    }
    
    // Handle hundreds
    if number < 1000 {
      let hundreds = number / 100
      let remainder = number % 100
      let hundredsWord = toCardinal(hundreds) + " hundred"
      if remainder == 0 {
        return hundredsWord
      } else {
        return "\(hundredsWord) and \(toCardinal(remainder))"
      }
    }
    
    // By the largest power of a thousand the number reaches. The thousands
    // used to be tried before the millions, and every number of 1,000 or more
    // is a count of thousands, so a million was never named: 5,000,000 read
    // "five thousand thousand" and 1,234,567 "one thousand two hundred
    // thirty-four thousand…".
    for (value, word) in scales where number >= value {
      let quotientWord = toCardinal(number / value)
      let remainder = number % value
      return remainder == 0 ? "\(quotientWord) \(word)" : "\(quotientWord) \(word), \(toCardinal(remainder))"
    }

    return ""
  }
  
  private func toYear(_ yearDecimal: Decimal, suffix: String? = nil, longVal: Bool = true) -> String {
    let year = NSDecimalNumber(decimal: yearDecimal).intValue
    var val = year
    var finalSuffix = suffix
    
    if val < 0 {
      val = abs(val)
      finalSuffix = finalSuffix ?? "BC"
    }
    
    let high = val / 100
    let low = val % 100
    
    let valText: String
    // If year is 00XX, X00X, or beyond 9999, go cardinal
    if high == 0 || (high % 10 == 0 && low < 10) || high >= 100 {
      valText = toCardinal(val)
    } else {
      let highText = toCardinal(high)
      let lowText: String
      if low == 0 {
        lowText = "hundred"
      } else if low < 10 {
        lowText = "oh-\(toCardinal(low))"
      } else {
        lowText = toCardinal(low)
      }
      valText = "\(highText) \(lowText)"
    }
    
    if let suffix = finalSuffix {
      return "\(valText) \(suffix)"
    } else {
      return valText
    }
  }
  
  /// A `Decimal` prints as its exact digits, and those are what is read. The
  /// whole part used to be taken with `NSDecimalNumber.intValue` and the
  /// fraction as what was left after subtracting it. `intValue` is wrong for
  /// a mantissa of 2^63 or more (3.14159265358979323846 gave 0), and a
  /// negative remainder printed "-0.5", whose "." was read as a digit: -2.5
  /// was "minus two point zero five".
  ///
  /// A value the reader refuses has no reading. That is a whole part past
  /// `Int`, where `intValue` used to answer: with the digits of another
  /// number, or `Int.min`, on which `toCardinal` traps ("1.2.1" and 63 zeros
  /// did, as one part of a dotted run).
  private func toDecimal(_ number: Decimal) -> String {
    let digits = "\(number)"
    let unsigned = digits.hasPrefix("-") ? String(digits.dropFirst()) : digits
    guard let words = convert(decimalText: unsigned) else { return "" }
    return unsigned.count == digits.count ? words : negWord + words
  }

  /// The digits of a fraction that are read. BetterFeeds spells a fraction of
  /// up to this many digits itself and leaves a longer one in digits so that
  /// it is not expanded; "pi is 3." and 200,000 digits is a real page. Read
  /// by value, a fraction stopped at the eighteen or so digits a `Double`
  /// made of it, the last of them wrong.
  static let maximumFractionDigits = 24

  /// Reads an unsigned decimal from its text: the whole part as a cardinal,
  /// then "point" and each digit of the fraction as it is written, a trailing
  /// zero included, up to `maximumFractionDigits`. Nil for text that is not
  /// digits around at most one point, or whose whole part is past `Int`.
  ///
  /// The lexicon used to read a decimal by value, as `Decimal(Double(text))`.
  /// That conversion is inexact for about one two-digit fraction in seven, so
  /// "6.77" arrived as 6.769999999999998976 and was read with all eighteen
  /// digits. Where the mantissa it made reaches 2^63, `toDecimal` took the
  /// whole part wrong as well: "14.96" was "minus three point zero nine six
  /// zero zero…", "1.06" opened on "zero". By value a written zero was also
  /// lost, "3.10" reading as "three point one" does. Upstream misaki reads
  /// through a float too and drops that zero; it is kept here.
  func convert(decimalText text: String) -> String? {
    // Held to the ten ASCII digits. `Int` alone would take a sign and then
    // lose it on "-0.5", so the caller says "minus".
    func isDigits(_ run: Substring) -> Bool { run.allSatisfy { $0.isASCII && $0.isWholeNumber } }

    let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard isDigits(parts[0]), let whole = Int(parts[0]) else { return nil }
    guard parts.count == 2, !parts[1].isEmpty else { return toCardinal(whole) }
    guard isDigits(parts[1]) else { return nil }

    let fraction = parts[1].prefix(Self.maximumFractionDigits).compactMap(\.wholeNumberValue).map(toCardinal)
    return ([toCardinal(whole), pointWord] + fraction).joined(separator: " ")
  }

  /// Converts a number representing year, oridnal number or a decimal (integer numbers included) to words
  func convert(_ number: Decimal, to format: ConversionFormat = .decimal) -> String {
    switch format {
    case .ordinal:
      return toOrdinal(number)
    case .ordinalNum:
      return toOrdinalNum(number)
    case .year:
      return toYear(number)
    case .decimal:
      return toDecimal(number)
    }
  }
}
