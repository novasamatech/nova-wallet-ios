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
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        DispatchQueue.main.async {
            guard
                let connection = connection as? ChainConnection,
                let nodeUrl = connection.urls.first
            else {
                return
            }

            switch newState {
            case .notConnected, .connecting, .waitingReconnection:
                self.presenter?.didReceive(.connecting, for: nodeUrl.absoluteString)
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

    func measureNodePing(for nodeUrl: URL) {
        guard
            let connection = nodesConnections[nodeUrl.absoluteString],
            let key = try? StorageKeyFactory().accountInfoKeyForId(
                AccountId.zeroAccountId(of: chain.accountIdSize)
            )
        else {
            return
        }

        let queryOperation = storageRequestFactory.queryOperation(
            for: { [key] },
            at: nil,
            engine: connection
        )

        let measureOperation = createPingMeasureOperation(with: queryOperation)

        execute(
            wrapper: measureOperation,
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

    func createPingMeasureOperation(with queryOperation: BaseOperation<[[StorageUpdate]]>) -> CompoundOperationWrapper<Int> {
        var startTime: CFAbsoluteTime?

        let operation = AsyncClosureOperation { resultClosure in
            let endTime = CFAbsoluteTimeGetCurrent()
            let ping = Int((endTime - (startTime ?? 0)) * 1000)

            resultClosure(.success(ping))
        }

        queryOperation.configurationBlock = {
            startTime = CFAbsoluteTimeGetCurrent()
        }

        operation.addDependency(queryOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: [queryOperation]
        )
    }
}

extension NetworkDetailsInteractor {
    enum ConnectionState {
        case connecting
        case connected
    }
}
