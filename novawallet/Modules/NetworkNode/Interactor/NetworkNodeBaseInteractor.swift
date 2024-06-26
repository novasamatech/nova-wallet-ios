import UIKit
import SubstrateSdk
import Operation_iOS

class NetworkNodeBaseInteractor {
    weak var basePresenter: NetworkNodeBaseInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    
    let chainId: ChainModel.Id
    
    let wssPredicate = NSPredicate.websocket
    
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
        chain: ChainModel
    ) {
        if let existingNode = findExistingNode(with: node.url, in: chain) {
            basePresenter?.didReceive(.alreadyExists(nodeName: existingNode.name))
            
            return
        }
        
        guard wssPredicate.evaluate(with: node.url) else {
            basePresenter?.didReceive(.wrongFormat)
            
            return
        }
        
        currentConnectingNode = node
        
        do {
            currentConnection = try connectionFactory.createConnection(
                for: node,
                chain: chain,
                delegate: self
            )
        } catch {
            basePresenter?.didReceive(.unableToConnect(networkName: chain.name))
        }
    }
    
    func findExistingNode(
        with url: String,
        in chain: ChainModel
    ) -> ChainNodeModel? {
        fatalError("Must be overriden by subclass")
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
    
    func substrateChainCorrespondingOperation(
        connection: JSONRPCEngine,
        node: ChainNodeModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        let genesisBlockOperation = blockHashOperationFactory.createBlockHashOperation(
            connection: connection,
            for: { 0 }
        )
    
        let checkChainCorrespondingOperation = ClosureOperation<Void> {
            let genesisHash = try genesisBlockOperation
                .extractNoCancellableResultData()
                .withoutHexPrefix()
            
            guard genesisHash == chain.chainId else {
                throw NetworkNodeBaseInteractorError.wrongNetwork(networkName: chain.name)
            }
        }
        
        checkChainCorrespondingOperation.addDependency(genesisBlockOperation)
        
        return CompoundOperationWrapper(
            targetOperation: checkChainCorrespondingOperation,
            dependencies: [genesisBlockOperation]
        )
    }
    
    func evmChainCorrespondingOperation(
        connection: JSONRPCEngine,
        node: ChainNodeModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        let chainIdOperation = EvmWebSocketOperationFactory(
            connection: connection,
            timeout: 10
        ).createChainIdOperation()
        
        let checkChainCorrespondingOperation = ClosureOperation<Void> {
            let actualChainId = try chainIdOperation.extractNoCancellableResultData()
            
            guard actualChainId.wrappedValue == chain.addressPrefix else {
                throw NetworkNodeBaseInteractorError.wrongNetwork(networkName: chain.name)
            }
        }
        
        checkChainCorrespondingOperation.addDependency(chainIdOperation)
        
        return CompoundOperationWrapper(
            targetOperation: checkChainCorrespondingOperation,
            dependencies: [chainIdOperation]
        )
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
