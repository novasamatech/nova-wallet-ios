import SubstrateSdk
import Foundation_iOS

typealias ChainAccountListViewModel = [ChainAccountListSectionViewModel]

struct ChainAccountListSectionViewModel {
    let section: ChainAccountSectionType
    let chainAccounts: [ChainAccountViewModelItem]
}

enum ChainAccountSectionType {
    struct Custom {
        let title: LocalizableResource<String>
        let action: LocalizableResource<IconWithTitleViewModel>?
    }

    case sharedSecret
    case customSecret
    case noSection
    case custom(Custom)

    var title: LocalizableResource<String>? {
        switch self {
        case let .custom(model):
            return model.title
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

    var action: LocalizableResource<IconWithTitleViewModel>? {
        switch self {
        case let .custom(model):
            return model.action
        case .customSecret, .sharedSecret, .noSection:
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
