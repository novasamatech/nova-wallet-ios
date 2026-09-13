import Foundation

enum TokensManageListItem: Hashable {
    case root(TokensManageRootViewModel)
    case child(TokensManageChildViewModel)
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
