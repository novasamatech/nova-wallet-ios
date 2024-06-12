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
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationQueue: OperationQueue

    private var nodesConnections: [String: ChainConnection] = [:]

    init(
        chain: ChainModel,
        connectionFactory: ConnectionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.connectionFactory = connectionFactory
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
    }
}

// MARK: NetworkDetailsInteractorInputProtocol

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {
    func setup() {
        connectToNodes(of: chain)
        subscribeChainChanges()
    }

    func toggleNetwork() {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            var updatedChain = chain.byChanging(enabled: !chain.enabled)

            if chain.enabled {
                updatedChain = updatedChain.updatingSelectedNode(with: nil)
                updatedChain = updatedChain.updatingConnectionMode(for: .manual)
            }

            return [updatedChain]
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

    func selectNode(_ node: ChainNodeModel) {
        let saveOperation = repository.saveOperation({ [weak self] in
            guard let self else { return [] }

            return [chain.updatingSelectedNode(with: node)]
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
        guard chainId == chain.chainId else { return }

        print(state)
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
            presenter?.didReceive(updatedChain: changedChain)
        }
    }

    func toggleNodesAfterChainUpdate(
        beforeChange chain: ChainModel,
        updatedChain: ChainModel
    ) {
        guard chain.enabled != updatedChain.enabled else {
            return
        }

        if updatedChain.enabled {
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
        guard
            let connection = nodesConnections[nodeUrl.absoluteString],
            let key = try? StorageKeyFactory().accountInfoKeyForId(
                AccountId.zeroAccountId(of: chain.accountIdSize)
            )
        else {
            return
        }

        let measureOperation: BaseOperation<Int> = if chain.isEthereumBased {
            createPingMeasureOperation(
                with: createEVMQueryOperation(with: connection),
                queue: operationQueue
            )
        } else {
            createPingMeasureOperation(
                with: storageRequestFactory.queryOperation(
                    for: { [key] },
                    at: nil,
                    engine: connection
                ),
                queue: operationQueue
            )
        }

        execute(
            operation: measureOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(ping):
                self?.presenter?.didReceive(
                    .pinged(ping),
                    for: nodeUrl.absoluteString
                )
            case let .failure(error):
                print(error)
            }
        }
    }

    func createEVMQueryOperation(with connection: ChainConnection) -> BaseOperation<Result<String, Error>> {
        AsyncClosureOperation { resultClosure in
            let params = EvmBalanceMessage.Params(
                holder: String(),
                block: .latest
            )
            _ = try connection.callMethod(
                EvmBalanceMessage.method,
                params: params,
                options: .init(resendOnReconnect: false)
            ) { (result: Result<String, Error>) in
                resultClosure(.success(result))
            }
        }
    }

    func createPingMeasureOperation<T>(
        with queryOperation: BaseOperation<T>,
        queue: OperationQueue
    ) -> BaseOperation<Int> {
        AsyncClosureOperation { resultClosure in
            let startTime = CFAbsoluteTimeGetCurrent()
            execute(
                operation: queryOperation,
                inOperationQueue: queue,
                runningCallbackIn: nil
            ) { _ in
                let endTime = CFAbsoluteTimeGetCurrent()
                let ping = Int((endTime - startTime) * 1000)

                resultClosure(.success(ping))
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
