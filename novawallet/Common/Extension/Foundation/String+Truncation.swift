import Foundation

extension String {
    func truncatedMiddle(
        limit: Int,
        replacementSymbol: String = "..."
    ) -> String {
        guard count > limit else { return self }

        let headCharactersCount = Int(ceil(Float(limit - replacementSymbol.count) / 2.0))

        let tailCharactersCount = Int(floor(Float(limit - replacementSymbol.count) / 2.0))

        return String(prefix(headCharactersCount))
            + replacementSymbol
            + String(suffix(tailCharactersCount))
    }
}
