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
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
