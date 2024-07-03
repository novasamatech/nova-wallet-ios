import Foundation
import SoraFoundation

final class KnownNetworksListPresenter {
    weak var view: KnownNetworksListViewProtocol?
    let wireframe: KnownNetworksListWireframeProtocol
    let interactor: KnownNetworksListInteractorInputProtocol
    
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private var chains: [ChainModel] = []
    init(
        interactor: KnownNetworksListInteractorInputProtocol,
        wireframe: KnownNetworksListWireframeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.networkViewModelFactory = networkViewModelFactory
    }
}

extension KnownNetworksListPresenter: KnownNetworksListPresenterProtocol {
    func setup() {
        interactor.provideChains()
    }
    
    func selectChain(at index: Int) {
        
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
                let networkType = chain.isTestnet
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
    
    func didReceive(chains: [ChainModel]) {
        self.chains = chains.sorted {
            ChainModelCompator.defaultComparator(
                chain1: $0,
                chain2: $1
            )
        }
    }
}

// MARK: Localizable

extension KnownNetworksListPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
        
        provideViewModels()
    }
}
