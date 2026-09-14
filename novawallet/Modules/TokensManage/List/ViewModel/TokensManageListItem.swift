import Foundation

enum TokensManageListItem: Hashable {
    case root(TokensManageRootViewModel)
    case child(TokensManageChildViewModel)

    var identifier: TokensManageListItemIdentifier {
        switch self {
        case let .root(viewModel):
            return .root(groupId: viewModel.groupId)
        case let .child(viewModel):
            return .child(groupId: viewModel.groupId, chainAssetId: viewModel.chainAssetId)
        }
    }
}

enum TokensManageListItemIdentifier: Hashable {
    case root(groupId: String)
    case child(groupId: String, chainAssetId: ChainAssetId)
}

enum TokensManageSectionKind: Hashable {
    case `default`
    case others
    case paused
    case results
}

struct TokensManageSection: Equatable {
    let kind: TokensManageSectionKind
    let title: String
    let items: [TokensManageListItem]
}
