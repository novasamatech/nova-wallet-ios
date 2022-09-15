import Foundation

extension String {
    static var returnKey: String { "\n" }

    func firstLetterCapitalized() -> String {
        prefix(1).capitalized + dropFirst()
    }
}
