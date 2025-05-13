import Foundation

struct PayShopBrandViewModel: Hashable {
    let identifier: String
    let iconViewModel: ImageViewModelProtocol?
    let name: String
    let commission: String?
    let commissionTitle: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
