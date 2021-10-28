import FearlessUtils
import SoraFoundation

typealias ChainAccountListViewModel = [ChainAccountListSectionViewModel]

struct ChainAccountListSectionViewModel {
    let section: ChainAccountSectionType
    let chainAccounts: [ChainAccountViewModelItem]
}

enum ChainAccountSectionType {
    case sharedSecret
    case customSecret

    var title: LocalizableResource<String> {
        LocalizableResource { locale in
            switch self {
            case .customSecret:
                return R.string.localizable
                    .chainAccountsSectionTitleCustomSecret(preferredLanguages: locale.rLanguages)

            case .sharedSecret:
                return R.string.localizable
                    .chainAccountsSectionTitleSharedSecret(preferredLanguages: locale.rLanguages)
            }
        }
    }
}

struct ChainAccountViewModelItem {
    let name: String
    let address: String
    let chainIcon: UIImage
    let accountIcon: DrawableIcon?
}
