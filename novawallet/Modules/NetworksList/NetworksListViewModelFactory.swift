import Foundation
import SoraFoundation

class NetworksListViewModelFactory {
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
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> NetworksListViewLayout.Model {
        .init(
            sections: [
                .networks(createRows(from: chains, with: connectionStates))
            ]
        )
    }

    func createAddedViewModel(
        for chains: [ChainModel],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> NetworksListViewLayout.Model {
        .init(
            sections: [
                .networks(createRows(from: chains, with: connectionStates))
            ]
        )
    }

    private func createRows(
        from chains: [ChainModel],
        with connectionStates: [ChainModel.Id: NetworksListPresenter.ConnectionState]
    ) -> [NetworksListViewLayout.Row] {
        chains.map { chainModel in
            let connectionState: String? = if connectionStates[chainModel.chainId] == .connecting {
                R.string.localizable.networkStatusConnecting(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                )
            } else {
                nil
            }

            return .network(
                .init(
                    connectionState: connectionState,
                    networkModel: networkViewModelFactory.createDiffableViewModel(from: chainModel)
                )
            )
        }
    }
}
