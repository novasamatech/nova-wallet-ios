import UIKit

struct WalletSwitchViewModel {
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
