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

private extension NSPredicate {
    static var ws: NSPredicate {
        let format = "^" +
            // protocol identifier (optional)
            // short syntax // still required
            "(?:(?:(?:wss?|ws):)?\\/\\/)" +
            // user:pass BasicAuth (optional)
            "(?:\\S+(?::\\S*)?@)?" +
            "(?:" +
            // IP address exclusion
            // private & local networks
            "(?!(?:10|127)(?:\\.\\d{1,3}){3})" +
            "(?!(?:169\\.254|192\\.168)(?:\\.\\d{1,3}){2})" +
            "(?!172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.\\d{1,3}){2})" +
            // IP address dotted notation octets
            // excludes loopback network 0.0.0.0
            // excludes reserved space >= 224.0.0.0
            // excludes network & broadcast addresses
            // (first & last IP address of each class)
            "(?:[1-9]\\d?|1\\d\\d|2[01]\\d|22[0-3])" +
            "(?:\\.(?:1?\\d{1,2}|2[0-4]\\d|25[0-5])){2}" +
            "(?:\\.(?:[1-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4]))" +
            "|" +
            // host & domain names, may end with dot
            // can be replaced by a shortest alternative
            // (?![-_])(?:[-\\w\\u00a1-\\uffff]{0,63}[^-_]\\.)+
            "(?:" +
            "(?:" +
            "[a-z0-9\\u00a1-\\uffff]" +
            "[a-z0-9\\u00a1-\\uffff_-]{0,62}" +
            ")?" +
            "[a-z0-9\\u00a1-\\uffff]\\." +
            ")+" +
            // TLD identifier name, may end with dot
            "(?:[a-z\\u00a1-\\uffff]{2,}\\.?)" +
            ")" +
            // port number (optional)
            "(?::\\d{2,5})?" +
            // resource path (optional)
            "(?:[/?#]\\S*)?" +
            "$"

        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
