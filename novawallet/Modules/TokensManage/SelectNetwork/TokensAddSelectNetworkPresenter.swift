import Foundation
import Operation_iOS

final class TokensAddSelectNetworkPresenter {
    weak var view: TokensAddSelectNetworkViewProtocol?
    let wireframe: TokensAddSelectNetworkWireframeProtocol
    let interactor: TokensAddSelectNetworkInteractorInputProtocol
    let viewModelFactory: NetworkViewModelFactoryProtocol

    private(set) var chains: [ChainModel.Id: ChainModel] = [:]
    private(set) var targetChains: [ChainModel] = []

    init(
        interactor: TokensAddSelectNetworkInteractorInputProtocol,
        wireframe: TokensAddSelectNetworkWireframeProtocol,
        viewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    func updateView() {
        let viewModels = targetChains.map { viewModelFactory.createDiffableViewModel(from: $0) }
        view?.didReceive(viewModels: viewModels)
    }

    func updateTargetChains() {
        targetChains = chains.values
            .filter(\.isEthereumBased)
            .sorted { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }
    }
}

extension TokensAddSelectNetworkPresenter: TokensAddSelectNetworkPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectChain(at index: Int) {
        wireframe.showTokenAdd(from: view, chain: targetChains[index])
    }
}

extension TokensAddSelectNetworkPresenter: TokensAddSelectNetworkInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        updateTargetChains()
        updateView()
    }
}
