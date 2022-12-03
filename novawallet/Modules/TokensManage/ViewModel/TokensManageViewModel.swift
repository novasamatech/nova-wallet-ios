import Foundation

struct TokensManageViewModel: Hashable {
    let symbol: String
    let imageViewModel: ImageViewModelProtocol?
    let subtitle: String
    let isOn: Bool

    static func == (lhs: TokensManageViewModel, rhs: TokensManageViewModel) -> Bool {
        lhs.symbol == rhs.symbol
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
    }
}
