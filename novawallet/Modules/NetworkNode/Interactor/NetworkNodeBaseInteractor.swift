import UIKit
import SubstrateSdk
import Operation_iOS

class NetworkNodeBaseInteractor: NetworkNodeConnectingTrait, NetworkNodeChainCorrespondingTrait {
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
                self.basePresenter?.didReceive(.unableToConnect(networkName: chain.name))
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
                self?.basePresenter?.didReceive(.wrongNetwork(networkName: chain.name))
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
    case alreadyExists(nodeName: String)
    case wrongNetwork(networkName: String)
    case unableToConnect(networkName: String)
    case wrongFormat
    
    case common(error: CommonError)
}
