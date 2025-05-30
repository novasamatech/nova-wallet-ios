import Foundation
import Foundation_iOS

class ManualBackupKeyListViewModelFactory {
    private let localizationManager: LocalizationManagerProtocol
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(
        localizationManager: LocalizationManagerProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.localizationManager = localizationManager
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(
        from defaultChains: [ChainModel],
        _ customChains: [ChainModel]
    ) -> ManualBackupKeyListViewLayout.Model {
        let listHeaderText = R.string.localizable.chainAccountsListHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        var sections: [ManualBackupKeyListViewLayout.Sections] = []

        if !defaultChains.isEmpty {
            sections.append(createDefaultChainsSection(for: defaultChains))
        }

        if !customChains.isEmpty {
            sections.append(createCustomChainsSection(for: customChains))
        }

        return .init(
            listHeaderText: listHeaderText,
            accountsSections: sections
        )
    }
}

// MARK: Private

private extension ManualBackupKeyListViewModelFactory {
    func createDefaultChainsSection(for chains: [ChainModel]) -> ManualBackupKeyListViewLayout.Sections {
        let defaultChainsHeaderText = R.string.localizable.chainAccountsListDefaultHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let defaultChainsTitleText = R.string.localizable.chainAccountsListDefaultTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .defaultKeys(
            .init(
                headerText: defaultChainsHeaderText.uppercased(),
                accounts: [
                    .init(
                        title: defaultChainsTitleText,
                        subtitle: formattedString(for: chains)
                    )
                ]
            )
        )
    }

    func createCustomChainsSection(for chains: [ChainModel]) -> ManualBackupKeyListViewLayout.Sections {
        let customChainsViewModels = chains
            .compactMap { chain -> ManualBackupKeyListViewLayout.CustomAccount? in

                ManualBackupKeyListViewLayout.CustomAccount(
                    network: self.networkViewModelFactory.createViewModel(from: chain),
                    chainId: chain.chainId
                )
            }

        let customChainsHeaderText = R.string.localizable.chainAccountsListCustomHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .customKeys(
            .init(
                headerText: customChainsHeaderText.uppercased(),
                accounts: customChainsViewModels
            )
        )
    }

    func formattedString(for defaultChains: [ChainModel]) -> String {
        let chainsToMention = defaultChains.count > 1
            ? defaultChains.prefix(2)
            : defaultChains.prefix(1)
        let restCount = defaultChains.count - chainsToMention.count
        let othersString = R.string.localizable.chainAccountsListDefaultSubtitle(
            restCount,
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        var joinedChains = chainsToMention
            .map(\.name)
            .joined(with: String.CompoundSeparator.commaSpace)

        return restCount > 0
            ? [joinedChains, othersString].joined(with: .commaSpace)
            : joinedChains
    }
}
