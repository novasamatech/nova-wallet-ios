import Foundation

extension String {
    static var returnKey: String { "\n" }
    static var readMore: String { "..." }
    static var empty: String = ""
    static var screenQuote: String { "\"" }

    func firstLetterCapitalized() -> String {
        prefix(1).capitalized + dropFirst()
    }

    func convertToReadMore(after threshold: Int) -> String {
        if count > threshold {
            return String(prefix(threshold)) + String.readMore
        } else {
            return self
        }
    }

    func isHex() -> Bool {
        hasPrefix("0x") && lengthOfBytes(using: .ascii) % 2 == 0
    }

    func withHexPrefix() -> String {
        if hasPrefix("0x") {
            return self
        } else {
            return "0x" + self
        }
    }

    func withoutHexPrefix() -> String {
        if hasPrefix("0x") {
            let indexStart = index(startIndex, offsetBy: 2)
            return String(self[indexStart...])
        } else {
            return self
        }
    }

    func inParenthesis() -> String {
        guard !isEmpty else {
            return ""
        }

        return "(\(self))"
    }

    func estimatedEqual(to other: String) -> String {
        "\(self) ≈ \(other)"
    }

    func approximately() -> String {
        "~\(self)"
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        guard let self = self else {
            return true
        }
        return self.isEmpty
    }
}
