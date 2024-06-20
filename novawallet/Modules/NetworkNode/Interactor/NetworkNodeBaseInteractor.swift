import UIKit
import SubstrateSdk
import Operation_iOS

class NetworkNodeBaseInteractor {
    weak var basePresenter: NetworkNodeBaseInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    
    let chainId: ChainModel.Id
    
    let wssPredicate = NSPredicate.websocket
    
    var currentConnection: ChainConnection?
    var currentConnectingNode: ChainNodeModel?
    
    init(
        chainRegistry: any ChainRegistryProtocol,
        connectionFactory: any ConnectionFactoryProtocol,
        chainId: ChainModel.Id,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.connectionFactory = connectionFactory
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
            let error = Errors.alreadyExists(nodeName: existingNode.name)
            basePresenter?.didReceive(error)
            
            return
        }
        
        guard wssPredicate.evaluate(with: node.url) else {
            basePresenter?.didReceive(Errors.wrongFormat)
            
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
            basePresenter?.didReceive(Errors.unableToConnect(networkName: chain.name))
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
                let chain = self.chainRegistry.getChain(for: self.chainId),
                let connection = connection as? ChainConnection
            else {
                return
            }

            switch newState {
            case .notConnected:
                self.basePresenter?.didReceive(Errors.unableToConnect(networkName: chain.name))
                self.currentConnection = nil
            case .waitingReconnection:
                connection.disconnect(true)
            case .connected:
                self.handleConnected()
            default:
                break
            }
        }
    }
}

// MARK: Errors

extension NetworkNodeBaseInteractor {
    enum Errors: Error {
        case alreadyExists(nodeName: String)
        case unableToConnect(networkName: String)
        case wrongFormat
    }
}

// MARK: Private

private extension NetworkNodeBaseInteractor {
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
