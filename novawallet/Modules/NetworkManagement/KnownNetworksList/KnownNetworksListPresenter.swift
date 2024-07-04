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

// MARK: KnownNetworksListPresenterProtocol

extension KnownNetworksListPresenter: KnownNetworksListPresenterProtocol {
    func setup() {
        provideViewModels()
        
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

// MARK: KnownNetworksListInteractorOutputProtocol

extension KnownNetworksListPresenter: KnownNetworksListInteractorOutputProtocol {
    func provideViewModels() {
        var sections: [KnownNetworksListViewLayout.Section] = []
        
        let addNetworkRow = KnownNetworksListViewLayout.Row.addNetwork(
            IconWithTitleViewModel(
                icon: R.image.iconAddNetwork(),
                title: R.string.localizable.networkAddNetworkManually(
                    preferredLanguages: selectedLocale.rLanguages
                )
            )
        )
        
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
        
        sections.append(.addNetwork([addNetworkRow]))
        
        if !chainRows.isEmpty {
            sections.append(.networks(chainRows))
        }
        
        let viewModel = KnownNetworksListViewLayout.Model(
            sections: sections
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
