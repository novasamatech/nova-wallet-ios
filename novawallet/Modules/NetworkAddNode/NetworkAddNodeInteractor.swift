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
    
    private var currentAddingNode: ChainNodeModel?
    private var currentConnection: ChainConnection?
    
    private var chain: ChainModel?
    
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
    func addNode(
        with url: String,
        name: String
    ) {
        do {
           try connectToNode(
            with: url,
            name: name
           )
        } catch {
            presenter?.didReceive(Errors.unableToCreateConnection)
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
                let connection = connection as? ChainConnection,
                let nodeUrl = connection.urls.first
            else {
                return
            }

            switch newState {
            case .notConnected:
                self.presenter?.didReceive(Errors.unableToConnect)
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
        case unableToConnect
        case unableToCreateConnection
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
        self.chain = chain
        
        currentConnection = try connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: self
        )
    }
    
    func handleConnected() {
        guard let currentAddingNode, let chain else { return }
        
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
}
