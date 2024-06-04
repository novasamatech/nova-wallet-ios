import Foundation
import SoraFoundation

class NetworksListViewModelFactory {
    typealias NetworkViewModel = NetworksListViewLayout.NetworkWithConnectionModel
    typealias NetorkListViewModel = NetworksListViewLayout.Model
    typealias RowModel = NetworksListViewLayout.Row

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
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

    private func createRows(
        from chains: [ChainModel],
        indexes: [ChainModel.Id: Int],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> [RowModel] {
        chains.map { chainModel in

            let connectionState: NetworkViewModel.ConnectionState

            if connectionStates[chainModel.chainId] == .connecting {
                connectionState = .connecting(
                    R.string.localizable.networkStatusConnecting(
                        preferredLanguages: localizationManager.selectedLocale.rLanguages
                    )
                )
            } else {
                connectionState = .connected
            }

            let networkState: NetworkViewModel.OverallState

            if chainModel.enabled {
                networkState = .enabled
            } else {
                networkState = .disabled(
                    R.string.localizable.commonDisabled(
                        preferredLanguages: localizationManager.selectedLocale.rLanguages
                    )
                )
            }

            return .network(
                .init(
                    index: indexes[chainModel.identifier]!,
                    networkType: chainModel.isTestnet ? "TESTNET" : nil,
                    connectionState: connectionState,
                    networkState: networkState,
                    networkModel: networkViewModelFactory.createDiffableViewModel(from: chainModel)
                )
            )
        }
    }
}
