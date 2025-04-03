import UIKit
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol?

    private let eventCenter: EventCenterProtocol

    private let connectionFactory: ConnectionFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let nodePingOperationFactory: NodePingOperationFactoryProtocol
    private let operationQueue: OperationQueue

    private var filteredNodes: Set<ChainNodeModel> = []
    private var nodesConnections: [String: ChainConnection] = [:]

    private var currentSelectedNode: ChainNodeModel?

    private var chain: ChainModel

    init(
        chain: ChainModel,
        eventCenter: EventCenterProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        nodePingOperationFactory: NodePingOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.eventCenter = eventCenter
        self.connectionFactory = connectionFactory
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.nodePingOperationFactory = nodePingOperationFactory
        self.operationQueue = operationQueue
    }
}

// MARK: NetworkDetailsInteractorInputProtocol

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        filteredNodes = filtered(chain.nodes)

        presenter?.didReceive(
            chain,
            filteredNodes: filteredNodes
        )

        subscribeChainChanges()

        guard chain.syncMode.enabled() else { return }

        connectToNodes(of: chain)
    }

    func setSetNetworkConnection(enabled: Bool) {
        let saveOperation = repository.saveOperation(
            { [weak self] in
                guard let self else { return [] }

                let updatedChain = enabled
                    ? chain.updatingSyncMode(for: .full)
                    : chain.updatingSyncMode(for: .disabled)

                return [updatedChain]
            },
            { [] }
        )

        executeDataOperationWithErrorHandling(saveOperation) { [weak self] in
            guard let chain = self?.chain else { return }

            self?.eventCenter.notify(
                with: NetworkEnabledChanged(
                    chainId: chain.chainId,
                    enabled: enabled
                )
            )
        }
    }

    func setAutoBalance(enabled: Bool) {
        let saveOperation = repository.saveOperation(
            { [weak self] in
                guard let self else { return [] }

                guard let currentSelectedNode, !enabled else {
                    return [chain.updatingConnectionMode(for: .autoBalanced)]
                }

                return [chain.updatingConnectionMode(for: .manual(currentSelectedNode))]
            },
            { [] }
        )

        executeDataOperationWithErrorHandling(saveOperation)
    }

    func selectNode(_ node: ChainNodeModel) {
        let saveOperation = repository.saveOperation(
            { [weak self] in
                guard let self else { return [] }

                return [chain.updatingConnectionMode(for: .manual(node))]
            },
            { [] }
        )

        executeDataOperationWithErrorHandling(saveOperation)
    }

    func deleteNode(_ node: ChainNodeModel) {
        delete(node, for: chain)
    }

    func deleteNetwork() {
        let deleteOperation = repository.saveOperation(
            { [] },
            { [weak self] in
                guard let self else { return [] }

                return [chain.chainId]
            }
        )

        executeDataOperationWithErrorHandling(deleteOperation) { [weak self] in
            self?.presenter?.didDeleteNetwork()
        }
    }
}

// MARK: WebSocketEngineDelegate

extension NetworkDetailsInteractor: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(_: AnyObject, newUrl _: URL) {}

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard oldState != newState else { return }

        DispatchQueue.main.async {
            guard
                let connection = connection as? ChainConnection,
                let nodeUrl = connection.urls.first
            else {
                return
            }

            switch newState {
            case .connecting, .waitingReconnection:
                self.presenter?.didReceive(
                    .connecting,
                    for: nodeUrl.absoluteString,
                    selected: false
                )
            case .notConnected:
                self.presenter?.didReceive(
                    .disconnected,
                    for: nodeUrl.absoluteString,
                    selected: false
                )
            case .connected:
                self.measureNodePing(
                    for: nodeUrl,
                    selected: self.currentSelectedNode?.url == nodeUrl.absoluteString
                )
            }
        }
    }
}

// MARK: ConnectionStateSubscription

extension NetworkDetailsInteractor: ConnectionStateSubscription {
    func didReceive(
        state: WebSocketEngine.State,
        for chainId: ChainModel.Id
    ) {
        guard
            chainId == chain.chainId,
            !chain.nodes.isEmpty
        else {
            return
        }

        switch state {
        case let .connected(selectedUrl):
            updateCurrentSelectedNode(with: selectedUrl)
            measureNodePing(
                for: selectedUrl,
                selected: true
            )
        case let .connecting(selectedUrl), let .waitingReconnection(selectedUrl):
            updateCurrentSelectedNode(with: selectedUrl)
            presenter?.didReceive(
                .connecting,
                for: selectedUrl.absoluteString,
                selected: true
            )
        case let .notConnected(selectedUrl):
            guard let selectedUrl else { return }

            presenter?.didReceive(
                .disconnected,
                for: selectedUrl.absoluteString,
                selected: selectedUrl.absoluteString == currentSelectedNode?.url
            )
        }
    }
}

// MARK: Private

private extension NetworkDetailsInteractor {
    func subscribeChainChanges() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let changedChain = changes
                .filter { change in
                    change.item?.chainId == self?.chain.chainId
                }
                .first?
                .item

            guard
                let self,
                let changedChain,
                chain != changedChain
            else {
                return
            }

            filteredNodes = filtered(changedChain.nodes)

            toggleNodesAfterChainUpdate(for: changedChain)

            presenter?.didReceive(
                changedChain,
                filteredNodes: filteredNodes
            )

            addNewNodesIfNeeded(for: changedChain)
            chain = changedChain
        }

        chainRegistry.subscribeChainState(
            self,
            chainId: chain.chainId
        )
    }

    func addNewNodesIfNeeded(for changedChain: ChainModel) {
        let newNodes = changedChain.nodes.subtracting(chain.nodes)

        guard !newNodes.isEmpty else { return }

        newNodes.forEach { connectTo($0, of: changedChain) }
    }

    func toggleNodesAfterChainUpdate(for changedChain: ChainModel) {
        guard chain.syncMode != changedChain.syncMode else {
            return
        }

        if changedChain.syncMode.enabled() {
            connectToNodes(of: changedChain)
        } else {
            disconnectNodes()
        }
    }

    func updateCurrentSelectedNode(with updatedUrl: URL?) {
        let newSelectedNode: ChainNodeModel = switch chain.connectionMode {
        case let .manual(chainNodeModel):
            chainNodeModel
        case .autoBalanced:
            chain.nodes.first { $0.url == updatedUrl?.absoluteString } ?? chain.nodes.first!
        }

        if let currentSelectedNode, currentSelectedNode.url != newSelectedNode.url {
            nodesConnections[newSelectedNode.url] = chainRegistry.getConnection(for: chain.chainId)
            connectTo(currentSelectedNode, of: chain)
        } else {
            nodesConnections[newSelectedNode.url] = chainRegistry.getConnection(for: chain.chainId)
        }

        currentSelectedNode = newSelectedNode
    }

    func connectToNodes(of chain: ChainModel) {
        filteredNodes.forEach { connectTo($0, of: chain) }
    }

    func delete(
        _ node: ChainNodeModel,
        for chain: ChainModel
    ) {
        let wrapper = nodeDeletionWrapper(node, chain: chain)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.nodesConnections[node.url] = nil

                if node.url == self?.currentSelectedNode?.url {
                    self?.currentSelectedNode = nil
                }
            case .failure:
                self?.presenter?.didReceive(CommonError.dataCorruption)
            }
        }
    }

    func nodeDeletionWrapper(
        _ node: ChainNodeModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        let updatedChain = if node == currentSelectedNode {
            chain
                .removing(node: node)
                .updatingConnectionMode(for: .autoBalanced)
        } else {
            chain.removing(node: node)
        }

        let updateOperation = repository.saveOperation(
            { [updatedChain] },
            { [] }
        )

        return CompoundOperationWrapper(targetOperation: updateOperation)
    }

    func connectTo(
        _ node: ChainNodeModel,
        of chain: ChainModel
    ) {
        guard let connection = try? connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: self
        ) else {
            return
        }

        nodesConnections[node.url] = connection
    }

    func disconnectNodes() {
        nodesConnections.values.forEach { connection in
            connection.disconnect(true)
        }

        nodesConnections = [:]
    }

    func measureNodePing(
        for nodeUrl: URL,
        selected: Bool
    ) {
        guard let connection = nodesConnections[nodeUrl.absoluteString] else {
            return
        }

        let nodePingOperation = nodePingOperationFactory.createOperation(
            for: chain,
            connection: connection
        )

        execute(
            operation: nodePingOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(ping):
                self?.presenter?.didReceive(
                    .pinged(ping),
                    for: nodeUrl.absoluteString,
                    selected: selected
                )
            case .failure:
                self?.presenter?.didReceive(
                    .unknown,
                    for: nodeUrl.absoluteString,
                    selected: selected
                )
            }
        }
    }

    func filtered(_ nodes: Set<ChainNodeModel>) -> Set<ChainNodeModel> {
        nodes.filter { NSPredicate.ws.evaluate(with: $0.url) }
    }

    func executeDataOperationWithErrorHandling(
        _ operation: BaseOperation<Void>,
        onSuccess: (() -> Void)? = nil
    ) {
        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                onSuccess?()
            case .failure:
                self?.presenter?.didReceive(CommonError.dataCorruption)
            }
        }
    }
}

extension NetworkDetailsInteractor {
    enum ConnectionState {
        case connecting
        case connected
    }
}
