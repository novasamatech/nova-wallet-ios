import Foundation

struct DAppViewModel {
    let identifier: String
    let name: String
    let details: String
    let icon: ImageViewModelProtocol?
    let isFavorite: Bool

    var order: Int?
}

// MARK: Hashable

extension DAppViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(isFavorite)
    }

    static func == (
        lhs: DAppViewModel,
        rhs: DAppViewModel
    ) -> Bool {
        lhs.identifier == rhs.identifier && lhs.isFavorite == rhs.isFavorite
    }
}
