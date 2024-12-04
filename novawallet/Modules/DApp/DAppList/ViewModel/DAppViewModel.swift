import Foundation

struct DAppViewModel {
    enum Identifier: Equatable, Hashable {
        case index(value: Int)
        case key(value: String)
    }

    let identifier: Identifier
    let name: String
    let details: String
    let icon: ImageViewModelProtocol?
    let isFavorite: Bool

    var order: Int? {
        switch identifier {
        case let .index(value):
            return value
        case .key:
            return nil
        }
    }
}

// MARK: Hashable

extension DAppViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (
        lhs: DAppViewModel,
        rhs: DAppViewModel
    ) -> Bool {
        lhs.identifier == rhs.identifier && lhs.isFavorite == rhs.isFavorite
    }
}
