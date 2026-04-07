import Foundation
import SubstrateSdk

struct WalletsListViewModel {
    let identifier: String
    let walletViewModel: WalletView.ViewModel
    let isSelected: Bool
    let isSelectable: Bool
    let isFavourite: Bool
    let typeBadge: String?

    init(
        identifier: String,
        walletViewModel: WalletView.ViewModel,
        isSelected: Bool,
        isSelectable: Bool = true,
        isFavourite: Bool = false,
        typeBadge: String? = nil
    ) {
        self.identifier = identifier
        self.walletViewModel = walletViewModel
        self.isSelected = isSelected
        self.isSelectable = isSelectable
        self.isFavourite = isFavourite
        self.typeBadge = typeBadge
    }
}

struct WalletsListSectionViewModel {
    enum SectionType: Hashable {
        case favourites
        case searchResults
        case secrets
        case watchOnly
        case paritySigner
        case ledger
        case polkadotVault
        case proxied
        case genericLedger
        case multisig

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
            case .multisig:
                self = .multisig
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
