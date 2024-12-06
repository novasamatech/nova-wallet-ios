import Foundation
import Operation_iOS

struct DAppFavorite: Identifiable {
    let identifier: String
    let label: String?
    let icon: String?
    let categories: [String]?
    let index: Int?

    func updatingIndex(to newIndex: Int?) -> Self {
        DAppFavorite(
            identifier: identifier,
            label: label,
            icon: icon,
            categories: categories,
            index: newIndex
        )
    }

    func incrementingIndex() -> Self {
        let newIndex: Int? = if let index = index {
            index + 1
        } else {
            nil
        }

        return updatingIndex(to: newIndex)
    }
}
