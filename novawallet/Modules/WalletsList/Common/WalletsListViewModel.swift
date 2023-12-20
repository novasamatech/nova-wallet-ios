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
        case proxied

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
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
