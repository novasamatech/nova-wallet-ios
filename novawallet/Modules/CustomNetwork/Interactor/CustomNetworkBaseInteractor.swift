import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait, NetworkNodeConnectingTrait {
    weak var basePresenter: CustomNetworkBaseInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    
    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?
    
    init(
        chainRegistry: any ChainRegistryProtocol,
        connectionFactory: any ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.operationQueue = operationQueue
    }
    
    func connectToChain(
        with networkType: ChainType,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    ) {
        let node = createNode(
            with: url,
            name: "My custom node",
            for: nil
        )
        
        
    }
}

// MARK: WebSocketEngineDelegate

extension CustomNetworkBaseInteractor: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(_: AnyObject, newUrl _: URL) {}

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
//        guard oldState != newState else { return }
//        
//        DispatchQueue.main.async {
//            guard
//                let node = self.currentConnectingNode,
//                let chain = self.chainRegistry.getChain(for: self.chainId),
//                let connection = connection as? ChainConnection
//            else {
//                return
//            }
//
//            switch newState {
//            case .notConnected:
//                self.currentConnection = nil
//            case .waitingReconnection:
//                connection.disconnect(true)
//            case .connected:
//                self.handleConnected(
//                    connection: connection,
//                    chain: chain,
//                    node: node
//                )
//            default:
//                break
//            }
//        }
    }
}

// MARK: CustomNetworkBaseInteractorInputProtocol

extension CustomNetworkBaseInteractor: CustomNetworkBaseInteractorInputProtocol {
    func setup() {}
}

enum ChainType {
    case substrate
    case evm
}
