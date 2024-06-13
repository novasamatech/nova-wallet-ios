import UIKit
import SubstrateSdk
import SoraFoundation
import Operation_iOS

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol?

    private var chain: ChainModel
    private let connectionFactory: ConnectionFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let nodePingOperationFactory: NodePingOperationFactoryProtocol
    private let operationQueue: OperationQueue

    private var nodesConnections: [String: ChainConnection] = [:]

    private var currentSelectedNode: ChainNodeModel?

    init(
        chain: ChainModel,
        connectionFactory: ConnectionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        nodePingOperationFactory: NodePingOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
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
        presenter?.didReceive(chain)

        connectToNodes(of: chain)
        subscribeChainChanges()
    }

    func setSetNetworkConnection(enabled: Bool) {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            var updatedChain = enabled
                ? chain.updatingSyncMode(for: .full)
                : chain.updatingSyncMode(for: .disabled)

            return [updatedChain]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func setAutoBalance(enabled: Bool) {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            guard let currentSelectedNode, !enabled else {
                return [chain.updatingConnectionMode(for: .autoBalanced)]
            }

            return [chain.updatingConnectionMode(for: .manual(currentSelectedNode))]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func selectNode(_ node: ChainNodeModel) {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            return [chain.updatingConnectionMode(for: .manual(node))]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
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
                self.presenter?.didReceive(.connecting, for: nodeUrl.absoluteString)
            case .notConnected:
                self.presenter?.didReceive(.disconnected, for: nodeUrl.absoluteString)
            case .connected:
                self.measureNodePing(for: nodeUrl)
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
            state == .connected
        else {
            return
        }

        let selectedNode: ChainNodeModel = switch chain.connectionMode {
        case let .manual(chainNodeModel):
            chainNodeModel
        case .autoBalanced:
            chain.nodes.first!
        }

        currentSelectedNode = selectedNode

        presenter?.didReceive(selectedNode)
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

            toggleNodesAfterChainUpdate(
                beforeChange: chain,
                updatedChain: changedChain
            )

            chain = changedChain
            presenter?.didReceive(changedChain)
        }

        chainRegistry.subscribeChainState(self, chainId: chain.chainId)
    }

    func toggleNodesAfterChainUpdate(
        beforeChange chain: ChainModel,
        updatedChain: ChainModel
    ) {
        guard chain.syncMode != updatedChain.syncMode else {
            return
        }

        if updatedChain.syncMode == .full {
            connectToNodes(of: updatedChain)
        } else {
            disconnectNodes()
        }
    }

    func connectToNodes(of chain: ChainModel) {
        nodesConnections = [:]

        chain.nodes.forEach { node in
            guard let connection = try? connectionFactory.createConnection(
                for: node,
                chain: chain,
                delegate: self
            ) else {
                return
            }

            nodesConnections[node.url] = connection
        }
    }

    func disconnectNodes() {
        nodesConnections.values.forEach { connection in
            connection.disconnect(true)
        }

        nodesConnections = [:]
    }

    func measureNodePing(for nodeUrl: URL) {
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
                    for: nodeUrl.absoluteString
                )
            case .failure:
                self?.presenter?.didReceive(
                    .unknown,
                    for: nodeUrl.absoluteString
                )
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
