import Foundation

extension String {
    func trimmingScreenQuotes() -> String {
        let pattern = Self.screenQuote

        guard hasPrefix(pattern), hasSuffix(pattern), count > pattern.count else {
            return self
        }

        let temp = prefix(count - pattern.count)

        return String(temp.suffix(temp.count - pattern.count))
    }
}
