import Foundation
import Foundation_iOS

extension WalletEmptyStateDataSource {
    static var history: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.walletEmptyDescription_v2_2_0()
        }

        let image = R.image.iconEmptyHistory()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }

    static var contacts: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSearchStartTitle_v2_2_0()
        }

        let image = R.image.iconEmptyHistory()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }

    static var search: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.walletSearchEmptyTitle_v1100()
        }

        let image = R.image.iconEmptySearch()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }
}
