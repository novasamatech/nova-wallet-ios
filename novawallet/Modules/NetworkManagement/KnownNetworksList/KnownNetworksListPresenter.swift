import Foundation
import SoraFoundation

final class KnownNetworksListPresenter {
    weak var view: KnownNetworksListViewProtocol?
    let wireframe: KnownNetworksListWireframeProtocol
    let interactor: KnownNetworksListInteractorInputProtocol
    
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private var chains: [LightChainModel] = []
    
    init(
        interactor: KnownNetworksListInteractorInputProtocol,
        wireframe: KnownNetworksListWireframeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
    }
}

extension KnownNetworksListPresenter: KnownNetworksListPresenterProtocol {
    func setup() {
        interactor.provideChains()
    }
    
    func selectChain(at index: Int) {
        let selectedLightChain = chains[index]
        
        interactor.provideChain(with: selectedLightChain.chainId)
    }
    
    func search(by query: String) {
        interactor.searchChain(by: query)
    }
    
    func addNetworkManually() {
        wireframe.showAddNetwork(
            from: view,
            with: nil
        )
    }
}

extension KnownNetworksListPresenter: KnownNetworksListInteractorOutputProtocol {
    func provideViewModels() {
        let chainRows: [KnownNetworksListViewLayout.Row] = chains
            .enumerated()
            .map { (index, chain) in
                let networkType = chain.options?.contains(.testnet) ?? false
                    ? R.string.localizable.commonTestnet(
                        preferredLanguages: selectedLocale.rLanguages
                    ).uppercased()
                    : nil
                
                let viewModel =  NetworksListViewLayout.NetworkWithConnectionModel(
                    index: index,
                    networkType: networkType,
                    connectionState: .connected,
                    networkState: .enabled,
                    networkModel: networkViewModelFactory.createDiffableViewModel(from: chain)
                )
                
                return .network(viewModel)
            }
        
        let viewModel = KnownNetworksListViewLayout.Model(
            sections: [
                .networks(chainRows)
            ]
        )

        view?.update(with: viewModel)
    }
    
    func didReceive(_ chains: [LightChainModel]) {
        self.chains = chains
        provideViewModels()
    }
    
    func didReceive(_ chain: ChainModel) {
        wireframe.showAddNetwork(
            from: view,
            with: chain
        )
    }
    
    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: Localizable

extension KnownNetworksListPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
        
        provideViewModels()
    }
}
