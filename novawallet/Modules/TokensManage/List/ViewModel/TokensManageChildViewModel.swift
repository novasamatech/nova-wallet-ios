import Foundation

struct TokensManageChildViewModel: Hashable {
    let groupId: String
    let chainAssetId: ChainAssetId
    let title: String
    let subtitle: String?
    let imageViewModel: ImageViewModelProtocol?
    let kind: Kind
    let isOn: Bool

    static func == (lhs: TokensManageChildViewModel, rhs: TokensManageChildViewModel) -> Bool {
        lhs.groupId == rhs.groupId &&
            lhs.chainAssetId == rhs.chainAssetId &&
            lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.isOn == rhs.isOn
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(groupId)
        hasher.combine(chainAssetId)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(isOn)
    }
}

extension TokensManageChildViewModel {
    enum Kind: Hashable {
        case network
        case token
    }
}
