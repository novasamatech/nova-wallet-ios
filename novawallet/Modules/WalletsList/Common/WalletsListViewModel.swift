import Foundation
import SubstrateSdk

struct WalletsListViewModel {
    let identifier: String
    let walletAmountViewModel: WalletTotalAmountView.ViewModel
    let isSelected: Bool
}

struct WalletsListSectionViewModel {
    enum SectionType {
        case secrets
        case watchOnly
        case paritySigner
        case ledger
        case polkadotVault

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
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
