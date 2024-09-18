import Foundation

extension String {
    func trimmingQuotes() -> String {
        trimmingPattern(Self.quote)
    }

    func trimmingPattern(_ pattern: String) -> String {
        guard hasPrefix(pattern), hasSuffix(pattern), count > pattern.count else {
            return self
        }

        let temp = prefix(count - pattern.count)

        return String(temp.suffix(temp.count - pattern.count))
    }
}
