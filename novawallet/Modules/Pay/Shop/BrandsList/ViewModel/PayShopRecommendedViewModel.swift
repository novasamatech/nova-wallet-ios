import Foundation

struct PayShopRecommendedViewModel: Hashable {
    let identifier: String
    let name: String
    let style: Style
    let commission: String?
    let imageViewModel: ImageViewModelProtocol?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

extension PayShopRecommendedViewModel {
    // TODO: Decide style
    struct Style {}
}
