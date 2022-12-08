import Foundation

struct TokensManageViewModel: Hashable {
    let identifier: Int
    let symbol: String
    let imageViewModel: ImageViewModelProtocol?
    let subtitle: String
    let isOn: Bool

    static func == (lhs: TokensManageViewModel, rhs: TokensManageViewModel) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
