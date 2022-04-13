import Foundation

struct DAppViewModel {
    enum Identifier {
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
