import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    private var chain: ChainModel
    private var sortedNodes = SortedNodes()
    private var connectionStates: [String: ConnectionState] = [:]
    private var nodes: [String: ChainNodeModel] = [:]
    private var nodesIndexes: [String: IndexPath] = [:]
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
        wireframe.showAddNode(
            from: view,
            chainId: chain.chainId
        )
    }

    func selectNode(at indexPath: IndexPath) {
        let node: ChainNodeModel = switch indexPath.section {
        case Constants.addNodeSectionIndex:
            sortedNodes.custom[indexPath.row - Constants.addNodeSectionNodeIndexOffset]
        default:
            sortedNodes.remote[indexPath.row]
        }
        
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

        sortedNodes = filteredNodes
            .sorted { $0.order < $1.order }
            .reduce(into: SortedNodes()) { acc, node  in
                switch node.source {
                case .remote:
                    acc.remote.append(node)
                case .user:
                    acc.custom.append(node)
                }
            }

        if filteredNodes.count == 1, let selectedNode = filteredNodes.first {
            self.selectedNode = selectedNode
        } else if case let .manual(selectedNode) = chain.connectionMode {
            self.selectedNode = selectedNode
        }

        indexNodes()
        provideViewModel()
    }

    func didReceive(
        _ connectionState: ConnectionState,
        for nodeURL: String,
        selected: Bool
    ) {
        guard connectionState != connectionStates[nodeURL] else { return }

        if selected {
            selectedNode = nodes[nodeURL]
        } else if selectedNode?.url == nodeURL {
            selectedNode = nil
        }

        connectionStates[nodeURL] = connectionState

        switch connectionState {
        case .connecting, .disconnected, .pinged, .unknown:
            provideNodeViewModel(for: nodeURL)
        default:
            break
        }
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
            connectionStates: connectionStates,
            onTapMore: editNode(at:)
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
        
        let viewModel = switch node.source {
        case .user:
            viewModelFactory.createAddNodeSection(
                with: [node],
                selectedNode: selectedNode,
                chain: chain,
                nodesIndexes: nodesIndexes,
                connectionStates: connectionStates,
                onTapMore: editNode(at:)
            )
        case .remote:
            viewModelFactory.createNodesSection(
                with: [node],
                selectedNode: selectedNode,
                chain: chain,
                nodesIndexes: nodesIndexes,
                connectionStates: connectionStates
            )
        }

        view?.updateNodes(with: viewModel)
    }

    func indexNodes() {
        nodesIndexes = [:]
        nodes = [:]
        
        sortedNodes.custom
            .enumerated()
            .forEach { index, node in
                nodes[node.url] = node
                nodesIndexes[node.url] = IndexPath(
                    row: index + Constants.addNodeSectionNodeIndexOffset,
                    section: Constants.addNodeSectionIndex
                )
            }
        
        sortedNodes.remote
            .enumerated()
            .forEach { index, node in
                nodes[node.url] = node
                nodesIndexes[node.url] = IndexPath(
                    row: index,
                    section: Constants.remoteNodesSectionIndex
                )
            }
    }
    
    func editNode(at indexPath: IndexPath) {
        let node = sortedNodes.custom[indexPath.row - Constants.addNodeSectionNodeIndexOffset]
        
        wireframe.showManageNode(
            from: view,
            node: node,
            onNodeEdit: { [weak self] in
                guard let self else { return }
                
                wireframe.showEditNode(
                    from: view,
                    node: node,
                    chainId: chain.chainId
                )
            },
            onNodeDelete: { print("DELETE") }
        )
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
    
    struct SortedNodes {
        var custom: [ChainNodeModel] = []
        var remote: [ChainNodeModel] = []
    }
    
    enum Constants {
        static let addNodeSectionIndex: Int = 1
        static let remoteNodesSectionIndex: Int = 2
        static let addNodeSectionNodeIndexOffset: Int = 1
    }
}
