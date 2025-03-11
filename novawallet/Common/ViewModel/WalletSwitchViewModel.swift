import Foundation

struct WalletSwitchViewModel {
    let identifier: String
    let type: WalletsListSectionViewModel.SectionType
    let iconViewModel: ImageViewModelProtocol?
    let hasNotification: Bool
}

// MARK: Hashable

extension WalletSwitchViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(type)
        hasher.combine(hasNotification)
    }

    static func == (lhs: WalletSwitchViewModel, rhs: WalletSwitchViewModel) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.type == rhs.type &&
            lhs.hasNotification == rhs.hasNotification
    }
}
