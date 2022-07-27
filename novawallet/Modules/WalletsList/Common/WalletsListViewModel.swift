import Foundation
import SubstrateSdk

struct WalletsListViewModel {
    let identifier: String
    let name: String
    let icon: ImageViewModelProtocol?
    let value: String?
    let isSelected: Bool
}

struct WalletsListSectionViewModel {
    enum SectionType {
        case secrets
        case watchOnly

        init(walletType: MetaAccountModelType) {
            switch walletType {
            case .secrets:
                self = .secrets
            case .watchOnly:
                self = .watchOnly
            }
        }
    }

    let type: SectionType
    let items: [WalletsListViewModel]
}
