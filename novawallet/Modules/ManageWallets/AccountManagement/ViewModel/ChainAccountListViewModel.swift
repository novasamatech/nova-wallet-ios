import SubstrateSdk
import Foundation_iOS

typealias ChainAccountListViewModel = [ChainAccountListSectionViewModel]

struct ChainAccountListSectionViewModel {
    let section: ChainAccountSectionType
    let chainAccounts: [ChainAccountViewModelItem]
}

enum ChainAccountSectionType {
    case sharedSecret
    case customSecret
    case noSection
    case custom(LocalizableResource<String>)

    var title: LocalizableResource<String>? {
        switch self {
        case let .custom(title):
            return title
        case .customSecret:
            return LocalizableResource { locale in
                R.string.localizable.chainAccountsSectionTitleCustomSecret(preferredLanguages: locale.rLanguages)
            }
        case .sharedSecret:
            return LocalizableResource { locale in
                R.string.localizable.chainAccountsSectionTitleSharedSecret(preferredLanguages: locale.rLanguages)
            }
        case .noSection:
            return nil
        }
    }
}

struct ChainAccountViewModelItem {
    let chainId: String
    let name: String
    let address: String?
    let warning: String?
    let chainIconViewModel: ImageViewModelProtocol?
    let accountIcon: DrawableIcon?
    let hasAction: Bool
}
