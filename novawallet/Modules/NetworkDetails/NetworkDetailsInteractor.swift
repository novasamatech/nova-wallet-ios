import UIKit
import SubstrateSdk
import SoraFoundation
import RobinHood

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol?

    private var chain: ChainModel
    private let connectionFactory: ConnectionFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let nodeMeasureQueue: OperationQueue

    private var nodesConnections: [String: ChainConnection] = [:]

    init(
        chain: ChainModel,
        connectionFactory: ConnectionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        nodeMeasureQueue: OperationQueue
    ) {
        self.chain = chain
        self.connectionFactory = connectionFactory
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationQueue = operationQueue
        self.nodeMeasureQueue = nodeMeasureQueue
    }
}

// MARK: NetworkDetailsInteractorInputProtocol

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        connectToChainNodes()
        subscribeChainChanges()
    }

    func toggleNetwork() {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            return [chain.byChanging(enabled: !chain.enabled)]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func toggleConnectionMode() {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            let newMode: ChainModel.ConnectionMode = if chain.connectionMode == .autoBalanced {
                .manual
            } else {
                .autoBalanced
            }

            return [chain.updatingConnectionMode(for: newMode)]
        }, {
            []
        })

        operationQueue.addOperation(saveOperation)
    }

    func selectNode(with url: String) {
        print(url)
    }
}

// MARK: WebSocketEngineDelegate

extension NetworkDetailsInteractor: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(_: AnyObject, newUrl _: URL) {}

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard
            let connection = connection as? ChainConnection,
            let nodeUrl = connection.urls.first
        else {
            return
        }

        switch newState {
        case .notConnected, .connecting, .waitingReconnection:
            presenter?.didReceive(.connecting, for: nodeUrl.absoluteString)
        case .connected:
            presenter?.didReceive(.connected, for: nodeUrl.absoluteString)
        }
    }
}

// MARK: ConnectionStateSubscription

extension NetworkDetailsInteractor: ConnectionStateSubscription {
    func didReceive(
        state: WebSocketEngine.State,
        for chainId: ChainModel.Id
    ) {
        guard chainId == chain.chainId else { return }

        print(state)
    }
}

extension NetworkDetailsInteractor {
    enum ConnectionState {
        case connecting
        case connected
    }
}

// MARK: Private

private extension NetworkDetailsInteractor {
    func measureConnection(for _: ChainNodeModel) {}

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
                let changedChain,
                self?.chain != changedChain
            else {
                return
            }

            self?.chain = changedChain
            self?.presenter?.didReceive(updatedChain: changedChain)
        }
    }

    func connectToChainNodes() {
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
}
