import Foundation
import SubstrateSdk

struct WalletsListViewModel {
    let identifier: String
    let walletViewModel: WalletView.ViewModel
    let isSelected: Bool
}

struct WalletsListSectionViewModel {
    enum SectionType {
        case secrets
        case watchOnly
        case paritySigner
        case ledger
        case polkadotVault
        case proxy

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
            case .proxy:
                self = .proxy
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
