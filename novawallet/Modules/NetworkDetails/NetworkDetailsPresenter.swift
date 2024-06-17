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
    private var selectedNode: ChainNodeModel?

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
    }
}

// MARK: NetworkDetailsPresenterProtocol

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func setNetwork(enabled: Bool) {
        interactor.setSetNetworkConnection(enabled: enabled)
    }

    func setAutoBalance(enabled: Bool) {
        interactor.setAutoBalance(enabled: enabled)
    }

    func addNode() {
        // TODO: Implement
    }

    func selectNode(at index: Int) {
        let node = sortedNodes[index]
        interactor.selectNode(node)
    }
}

// MARK: NetworkDetailsInteractorOutputProtocol

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {
    func didReceive(
        _ chain: ChainModel,
        filteredNodes: Set<ChainNodeModel>
    ) {
        self.chain = chain

        sortedNodes = filteredNodes.sorted { $0.order < $1.order }

        if sortedNodes.count == 1 {
            selectedNode = sortedNodes[0]
        } else if case let .manual(selectedNode) = chain.connectionMode {
            self.selectedNode = selectedNode
        }

        indexNodes()
        provideViewModel()
    }

    func didReceive(
        _ connectionState: ConnectionState,
        for nodeURL: String
    ) {
        guard connectionState != connectionStates[nodeURL] else { return }

        connectionStates[nodeURL] = connectionState

        switch connectionState {
        case .connecting, .disconnected, .pinged, .unknown:
            provideNodeViewModel(for: nodeURL)
        default:
            break
        }
    }

    func didReceive(_ selectedNode: ChainNodeModel) {
        self.selectedNode = selectedNode

        provideNodeViewModel(for: selectedNode.url)
    }
}

// MARK: Private

private extension NetworkDetailsPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: chain,
            nodes: sortedNodes,
            selectedNode: selectedNode,
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
            selectedNode: selectedNode,
            chain: chain,
            nodesIndexes: nodesIndexes,
            connectionStates: connectionStates
        )

        view?.updateNodes(with: viewModel)
    }

    func indexNodes() {
        nodesIndexes = [:]
        nodes = [:]

        sortedNodes.enumerated().forEach { index, node in
            nodesIndexes[node.url] = index
            nodes[node.url] = node
        }
    }
}

extension NetworkDetailsPresenter {
    enum ConnectionState: Equatable {
        case connecting
        case connected
        case disconnected
        case pinged(Int)
        case unknown
    }
}
