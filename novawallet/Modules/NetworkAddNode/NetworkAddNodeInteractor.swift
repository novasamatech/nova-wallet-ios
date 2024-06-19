import UIKit
import SubstrateSdk
import Operation_iOS

final class NetworkAddNodeInteractor {
    weak var presenter: NetworkAddNodeInteractorOutputProtocol?
    
    private let chainRegistry: ChainRegistryProtocol
    private let connectionFactory: ConnectionFactoryProtocol
    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    
    private let chainId: ChainModel.Id
    
    private let wssPredicate = NSPredicate.websocket
    
    private var currentAddingNode: ChainNodeModel?
    private var currentConnection: ChainConnection?
    
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
}

// MARK: NetworkAddNodeInteractorInputProtocol

extension NetworkAddNodeInteractor: NetworkAddNodeInteractorInputProtocol {
    func setup() {
        subscribeChainChanges()
    }
    
    func addNode(
        with url: String,
        name: String
    ) {
        guard let chain = chainRegistry.getChain(for: chainId) else { return }
        
        if let existingNode = chain.nodes.first { $0.url == url } {
            let error = Errors.alreadyExists(nodeName: existingNode.name)
            presenter?.didReceive(error)
            
            return
        }
        
        guard wssPredicate.evaluate(with: url) else {
            presenter?.didReceive(Errors.wrongFormat)
            
            return
        }
        
        do {
            try connectToNode(
                with: url,
                name: name
            )
        } catch {
            presenter?.didReceive(Errors.unableToConnect(networkName: chain.name))
        }
    }
}

// MARK: WebSocketEngineDelegate

extension NetworkAddNodeInteractor: WebSocketEngineDelegate {
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
                self.presenter?.didReceive(Errors.unableToConnect(networkName: chain.name))
            case .connected:
                self.handleConnected()
            default:
                break
            }
        }
    }
}

extension NetworkAddNodeInteractor {
    enum Errors: Error {
        case alreadyExists(nodeName: String)
        case unableToConnect(networkName: String)
        case wrongFormat
    }
}

// MARK: Private

private extension NetworkAddNodeInteractor {
    func connectToNode(
        with url: String,
        name: String
    ) throws {
        guard let chain = chainRegistry.getChain(for: chainId) else {
            return
        }
        
        let node = ChainNodeModel(
            url: url,
            name: name,
            order: 0,
            features: nil,
            source: .user
        )
        
        currentAddingNode = node
        
        currentConnection = try connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: self
        )
    }
    
    func handleConnected() {
        guard
            let currentAddingNode,
            let chain = chainRegistry.getChain(for: chainId)
        else { return }
        
        let saveOperation = repository.saveOperation(
            { [chain.adding(node: currentAddingNode)] },
            { [] }
        )
        
        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.presenter?.didAddNode()
            }
        }

        operationQueue.addOperation(saveOperation)
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

            presenter?.didReceive(changedChain)
        }
    }
}
