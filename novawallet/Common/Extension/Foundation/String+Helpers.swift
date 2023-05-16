import Foundation

extension String {
    static var returnKey: String { "\n" }
    static var readMore: String { "..." }

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
}
