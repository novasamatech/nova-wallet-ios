import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    private var chain: ChainModel
    private var sortedNodes: [ChainNodeModel] = []
    private let viewModelFactory: NetworkDetailsViewModelFactory

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        chain: ChainModel,
        viewModelFactory: NetworkDetailsViewModelFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.viewModelFactory = viewModelFactory

        sortedNodes = chain.nodes.sorted { $0.order < $1.order }
    }
}

// MARK: NetworkDetailsPresenterProtocol

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
        provideViewModel()
    }

    func toggleEnabled() {
        interactor.toggleNetwork()
    }

    func toggleConnectionMode() {
        interactor.toggleConnectionMode()
    }

    func addNode() {
        // TODO: Implement
    }

    func selectNode(at index: Int) {
        let url = sortedNodes[index].url
        interactor.selectNode(with: url)
    }
}

// MARK: NetworkDetailsInteractorOutputProtocol

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {
    func didReceive(updatedChain: ChainModel) {
        chain = updatedChain
        sortedNodes = updatedChain.nodes.sorted { $0.order < $1.order }

        provideViewModel()
    }
}

// MARK: Private

private extension NetworkDetailsPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(for: chain)
        view?.update(with: viewModel)
    }
}
