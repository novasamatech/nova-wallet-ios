import Foundation

enum TokensManageIcon {
    case asset(String?)
    case chain(ChainModel)
}

struct TokensManageMember {
    let chainAssetId: ChainAssetId
    let title: String
    let subtitle: String?
    let icon: TokensManageIcon
    let symbol: String
    let chainName: String
    let isVisible: Bool
}

struct TokensManageGroup {
    let id: String
    let title: String
    let icon: TokensManageIcon
    let kind: Kind
    let isPaused: Bool
    let members: [TokensManageMember]

    var isExpandable: Bool {
        members.count > 1 && !isPaused
    }
}

extension TokensManageGroup {
    enum Kind {
        case token
        case network
    }
}

struct TokensManageGroupSection {
    let kind: TokensManageSectionKind
    let groups: [TokensManageGroup]
}
