import UIKit

// TODO: Get rid of it
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

struct WWalletSwitchViewModel {
    let name: String
    let type: MetaAccountModelType
    let hasNotification: Bool

    var icon: UIImage? {
        switch type {
        case .secrets:
            nil
        case .watchOnly:
            R.image.iconWatchOnlyHeader()
        case .ledger:
            R.image.iconLedgerHeaderWarning()
        case .genericLedger:
            R.image.iconLedgerHeader()
        case .paritySigner:
            R.image.iconParitySignerHeader()
        case .polkadotVault:
            R.image.iconPolkadotVaultHeader()
        case .proxied:
            R.image.iconProxy()
        }
    }
}
