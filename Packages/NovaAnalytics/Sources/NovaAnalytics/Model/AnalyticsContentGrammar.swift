import Foundation

/// Membership is checked per unicode scalar rather than per `Character`: canonical equivalence
/// would otherwise let U+212A KELVIN SIGN pass as "K".
struct AnalyticsContentGrammar {
    let alphabet: CharacterSet
    let lengths: ClosedRange<Int>

    func accepts(_ value: String) -> Bool {
        let scalars = value.unicodeScalars

        guard lengths.contains(scalars.count) else {
            return false
        }

        return scalars.allSatisfy { $0.isASCII && alphabet.contains($0) }
    }
}

extension AnalyticsContentGrammar {
    enum Alphabet {
        static let lowercase = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        static let uppercase = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        static let digits = CharacterSet(charactersIn: "0123456789")
        static let letters = lowercase.union(uppercase)
        static let alphanumerics = letters.union(digits)
    }
}
