import Foundation

struct TokensManageHeaderActionViewModel: Equatable {
    let kind: Kind
    let isEnabled: Bool
}

extension TokensManageHeaderActionViewModel {
    enum Kind {
        case selectAll
        case deselectAll
    }
}
