import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    private var chain: ChainModel
    private var sortedNodes: [MeasuredNode] = []
    private var nodes: [String: MeasuredNode] = [:]
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

        sortedNodes = chain.nodes
            .sorted { $0.order < $1.order }
            .map { .init(connectionState: .connecting, node: $0) }
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
        let url = sortedNodes[index].node.url
        interactor.selectNode(with: url)
    }
}

// MARK: NetworkDetailsInteractorOutputProtocol

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {
    func didReceive(updatedChain: ChainModel) {
        chain = updatedChain
        sortedNodes = chain.nodes
            .sorted { $0.order < $1.order }
            .map { .init(connectionState: .connecting, node: $0) }

        indexNodes()
        provideViewModel()
    }

    func didReceive(measuredNode: MeasuredNode) {
        nodes[measuredNode.node.url] = measuredNode

        provideNodeViewModel(for: measuredNode.node.url)
    }
}

// MARK: Private

private extension NetworkDetailsPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: chain,
            nodes: sortedNodes,
            nodesIndexes: nodesIndexes
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

        let viewModel = viewModelFactory.createViewModel(
            for: chain,
            nodes: [node],
            nodesIndexes: nodesIndexes
        )

        view?.updateNodes(with: viewModel)
    }

    func indexNodes() {
        nodesIndexes = [:]

        sortedNodes.enumerated().forEach { index, measuredNode in
            nodesIndexes[measuredNode.node.url] = index
        }
    }
}
