import Foundation

struct TokensManageRootViewModel: Hashable {
    let groupId: String
    let title: String
    let subtitle: String
    let imageViewModel: ImageViewModelProtocol?
    let iconShape: IconShape
    let isOn: Bool
    let isExpandable: Bool
    let isExpanded: Bool
    let isPaused: Bool

    static func == (lhs: TokensManageRootViewModel, rhs: TokensManageRootViewModel) -> Bool {
        lhs.groupId == rhs.groupId &&
            lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.iconShape == rhs.iconShape &&
            lhs.isOn == rhs.isOn &&
            lhs.isExpandable == rhs.isExpandable &&
            lhs.isExpanded == rhs.isExpanded &&
            lhs.isPaused == rhs.isPaused
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(groupId)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(iconShape)
        hasher.combine(isOn)
        hasher.combine(isExpandable)
        hasher.combine(isExpanded)
        hasher.combine(isPaused)
    }
}

extension TokensManageRootViewModel {
    enum IconShape: Hashable {
        case circle
        case roundedSquare
    }
}
