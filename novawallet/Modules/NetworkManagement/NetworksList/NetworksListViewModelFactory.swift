import Foundation
import Foundation_iOS
import Keystore_iOS

class NetworksListViewModelFactory {
    typealias NetworkViewModel = NetworksListViewLayout.NetworkWithConnectionModel
    typealias NetorkListViewModel = NetworksListViewLayout.Model
    typealias SectionModel = NetworksListViewLayout.Section
    typealias RowModel = NetworksListViewLayout.Row

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let settingsManager: SettingsManagerProtocol

    init(
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        settingsManager: SettingsManagerProtocol
    ) {
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
        self.settingsManager = settingsManager
    }

    func createDefaultViewModel(
        for chains: [ChainModel],
        indexes: [ChainModel.Id: Int],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> NetorkListViewModel {
        .init(
            sections: [
                .networks(
                    createRows(
                        from: chains,
                        indexes: indexes,
                        with: connectionStates
                    )
                )
            ]
        )
    }

    func createAddedViewModel(
        for chains: [ChainModel],
        indexes: [ChainModel.Id: Int],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> NetorkListViewModel {
        var sections: [SectionModel] = []

        if settingsManager.integrateNetworksBannerSeen == false {
            sections.append(.banner([.banner]))
        }

        sections.append(
            .networks(
                createRows(
                    from: chains,
                    indexes: indexes,
                    with: connectionStates
                )
            )
        )

        return .init(sections: sections)
    }

    private func createRows(
        from chains: [ChainModel],
        indexes: [ChainModel.Id: Int],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> [RowModel] {
        guard !chains.isEmpty else {
            return [
                .placeholder(
                    .init(
                        message: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.networksListPlaceholderMesssage(),
                        buttonTitle: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.networksListAddNetworkButtonTitle()
                    )
                )
            ]
        }

        return chains.map { chainModel in

            let connectionState: NetworkViewModel.ConnectionState

            if connectionStates[chainModel.chainId] == .connected {
                connectionState = .connected
            } else if connectionStates[chainModel.chainId] == .notConnected {
                connectionState = .notConnected
            } else {
                connectionState = .connecting(
                    R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkStatusConnecting().uppercased()
                )
            }

            let networkState: NetworkViewModel.OverallState

            if chainModel.syncMode.enabled() {
                networkState = .enabled
            } else {
                networkState = .disabled(
                    R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.commonDisabled()
                )
            }

            let networkType: String? = chainModel.isTestnet
                ? R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.commonTestnet().uppercased()
                : nil

            return .network(
                .init(
                    index: indexes[chainModel.identifier]!,
                    networkType: networkType,
                    connectionState: connectionState,
                    networkState: networkState,
                    networkModel: networkViewModelFactory.createDiffableViewModel(from: chainModel)
                )
            )
        }
    }
}
