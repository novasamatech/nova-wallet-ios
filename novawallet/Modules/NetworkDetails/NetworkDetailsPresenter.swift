import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    private var chain: ChainModel
    private var sortedNodes: [ChainNodeModel] = []
    private var connectionStates: [String: ConnectionState] = [:]
    private var nodes: [String: ChainNodeModel] = [:]
    private var nodesIndexes: [String: Int] = [:]

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
        indexNodes()
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
        sortedNodes = chain.nodes.sorted { $0.order < $1.order }

        indexNodes()
        provideViewModel()
    }

    func didReceive(
        _ connectionState: ConnectionState,
        for nodeURL: String
    ) {
        connectionStates[nodeURL] = connectionState

        switch connectionState {
        case .connecting, .pinged:
            provideNodeViewModel(for: nodeURL)
        case .connected:
            print(connectionState)
        }
    }
}

// MARK: Private

private extension NetworkDetailsPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: chain,
            nodes: sortedNodes,
            nodesIndexes: nodesIndexes,
            connectionStates: connectionStates
        )
        view?.update(with: viewModel)
    }

    func provideNodeViewModel(for url: String) {
        guard
            let node = nodes[url],
            nodesIndexes[url] != nil
        else {
            return
        }

        let viewModel = viewModelFactory.createNodesSection(
            with: [node],
            nodesIndexes: nodesIndexes,
            connectionStates: connectionStates
        )

        view?.updateNodes(with: viewModel)
    }

    func indexNodes() {
        nodesIndexes = [:]

        sortedNodes.enumerated().forEach { index, node in
            nodesIndexes[node.url] = index
        }
    }
}

extension NetworkDetailsPresenter {
    enum ConnectionState {
        case connecting
        case connected
        case pinged(TimeInterval)
    }
}
