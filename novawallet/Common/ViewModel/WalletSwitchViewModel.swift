import Foundation

struct WalletSwitchViewModel {
    let type: WalletsListSectionViewModel.SectionType
    let iconViewModel: ImageViewModelProtocol?
    let hasNotification: Bool
}

// MARK: Hashable

extension WalletSwitchViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(hasNotification)
    }
    
    static func == (lhs: WalletSwitchViewModel, rhs: WalletSwitchViewModel) -> Bool {
        lhs.type == rhs.type && lhs.hasNotification == rhs.hasNotification
    }
}
