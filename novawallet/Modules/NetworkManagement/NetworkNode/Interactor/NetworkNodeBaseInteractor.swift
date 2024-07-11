import UIKit
import SubstrateSdk
import Operation_iOS

class NetworkNodeBaseInteractor: NetworkNodeConnectingTrait, NetworkNodeCorrespondingTrait {
    weak var basePresenter: NetworkNodeBaseInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    let chainId: ChainModel.Id

    let wssPredicate = NSPredicate.ws

    var currentConnection: ChainConnection?
    var currentConnectingNode: ChainNodeModel?

    init(
        chainRegistry: any ChainRegistryProtocol,
        connectionFactory: any ConnectionFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        chainId: ChainModel.Id,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.connectionFactory = connectionFactory
        self.blockHashOperationFactory = blockHashOperationFactory
        self.chainId = chainId
        self.repository = repository
        self.operationQueue = operationQueue
    }

    func completeSetup() {
        subscribeChainChanges()
    }

    func setup() {
        completeSetup()
    }

    func connect(
        to node: ChainNodeModel,
        replacing _: ChainNodeModel?,
        chain: ChainNodeConnectable
    ) {
        do {
            try connect(
                to: node,
                replacing: nil,
                chain: chain,
                urlPredicate: NSPredicate.ws
            )
        } catch {
            if let nodeCorrespondingError = error as? NetworkNodeCorrespondingError {
                basePresenter?.didReceive(.nodeValidation(innerError: nodeCorrespondingError))
            } else if let nodeConnectionError = error as? NetworkNodeConnectingError {
                basePresenter?.didReceive(.connection(innerError: nodeConnectionError))
            } else if let commonError = error as? CommonError {
                basePresenter?.didReceive(.common(innerError: commonError))
            } else {
                basePresenter?.didReceive(.common(innerError: .undefined))
            }
        }
    }

    func handleConnected() {
        fatalError("Must be overriden by subclass")
    }
}

// MARK: WebSocketEngineDelegate

extension NetworkNodeBaseInteractor: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(_: AnyObject, newUrl _: URL) {}

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard oldState != newState else { return }

        DispatchQueue.main.async {
            guard
                let node = self.currentConnectingNode,
                let chain = self.chainRegistry.getChain(for: self.chainId),
                let connection = connection as? ChainConnection
            else {
                return
            }

            switch newState {
            case .notConnected:
                self.basePresenter?.didReceive(
                    .connection(innerError: .unableToConnect(networkName: chain.name))
                )
                self.currentConnection = nil
            case .waitingReconnection:
                connection.disconnect(true)
            case .connected:
                self.handleConnected(
                    connection: connection,
                    chain: chain,
                    node: node
                )
            default:
                break
            }
        }
    }
}

// MARK: Private

private extension NetworkNodeBaseInteractor {
    func handleConnected(
        connection: ChainConnection,
        chain: ChainModel,
        node: ChainNodeModel
    ) {
        let chainCorrespondingOperation = chain.isEthereumBased
            ? evmChainCorrespondingOperation(
                connection: connection,
                node: node,
                chain: chain
            )
            : substrateChainCorrespondingOperation(
                connection: connection,
                node: node,
                chain: chain
            )

        execute(
            wrapper: chainCorrespondingOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.handleConnected()
            case .failure:
                self?.basePresenter?.didReceive(
                    .nodeValidation(innerError: .init(networkName: chain.name))
                )
            }
        }
    }

    func subscribeChainChanges() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let changedChain = changes
                .first { $0.item?.chainId == self?.chainId }?.item

            guard
                let self,
                let changedChain
            else {
                return
            }

            basePresenter?.didReceive(changedChain)
        }
    }
}

// MARK: Errors

enum NetworkNodeBaseInteractorError: Error {
    case connection(innerError: NetworkNodeConnectingError)
    case nodeValidation(innerError: NetworkNodeCorrespondingError)
    case common(innerError: CommonError)
}

extension NetworkNodeBaseInteractorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let error: ErrorContentConvertible = switch self {
        case let .connection(innerError): innerError
        case let .nodeValidation(innerError): innerError
        case let .common(innerError): innerError
        }

        return error.toErrorContent(for: locale)
    }
}
