import Foundation
import SubstrateSdk

struct WalletsListViewModel {
    let identifier: String
    let walletViewModel: WalletView.ViewModel
    let isSelected: Bool
}

struct WalletsListSectionViewModel {
    enum SectionType: Hashable {
        case secrets
        case watchOnly
        case paritySigner
        case ledger
        case polkadotVault
        case proxied
        case genericLedger

        init(walletType: MetaAccountModelType) {
            switch walletType {
            case .secrets:
                self = .secrets
            case .watchOnly:
                self = .watchOnly
            case .paritySigner:
                self = .paritySigner
            case .ledger:
                self = .ledger
            case .polkadotVault:
                self = .polkadotVault
            case .proxied:
                self = .proxied
            case .genericLedger:
                self = .genericLedger
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
