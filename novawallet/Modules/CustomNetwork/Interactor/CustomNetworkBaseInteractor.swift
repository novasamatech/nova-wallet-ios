import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait, NetworkNodeConnectingTrait, NetworkNodeChainCorrespondingTrait {
    weak var basePresenter: CustomNetworkBaseInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    
    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?
    
    var partialChain: ChainModel?
    
    init(
        chainRegistry: ChainRegistryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.blockHashOperationFactory = blockHashOperationFactory
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.operationQueue = operationQueue
    }
    
    func handleSetupFinished(for network: ChainModel) {
        fatalError("Must be overriden by subclass")
    }
    
    func completeSetup() {
        fatalError("Must be overriden by subclass")
    }
    
    func setup() {
        completeSetup()
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
        let evmChainId: UInt16? = if let chainId, let intChainId = Int(chainId) {
            UInt16(intChainId)
        } else {
            nil
        }
        
        let node = createNode(
            with: url,
            name: "My custom node",
            for: nil
        )
        
        let partialChain = ChainModel.partialCustomChainModel(
            ethereumBased: networkType == .evm,
            url: url,
            name: name,
            currencySymbol: currencySymbol,
            chainId: evmChainId,
            blockExplorer: nil,
            coingeckoURL: nil
        )
        
        self.partialChain = partialChain
        
        do {
            try connect(
                to: node,
                replacing: nil,
                chain: partialChain,
                urlPredicate: NSPredicate.ws
            )
        } catch {
            
        }
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
        guard oldState != newState else { return }
        
        DispatchQueue.main.async {
            guard
                let node = self.currentConnectingNode,
                let chain = self.partialChain,
                let connection = connection as? ChainConnection
            else {
                return
            }

            switch newState {
            case .notConnected:
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

private extension CustomNetworkBaseInteractor {
    func handleConnected(
        connection: ChainConnection,
        chain: ChainModel,
        node: ChainNodeModel
    ) {
        let finishSetupWrapper = finishChainSetupWrapper(
            chain: chain,
            connection: connection,
            node: node
        )
        
        execute(
            wrapper: finishSetupWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chain):
                self?.handleSetupFinished(for: chain)
            case let .failure(error):
                print(error)
            }
        }
    }
    
    func finishChainSetupWrapper(
        chain: ChainModel,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel> {
        let chainIdSetupWrapper = createChainIdSetupWrapper(
            chain: chain,
            connection: connection,
            node: node
        )
        
        let finishSetupWrapper = ClosureOperation<ChainModel> {
            let chainModel = try chainIdSetupWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .adding(node: node)
            
            return chainModel
        }
        
        let wrapper = CompoundOperationWrapper(targetOperation: finishSetupWrapper)
        wrapper.addDependency(wrapper: chainIdSetupWrapper)
        
        return chainIdSetupWrapper
    }
    
    func createChainIdSetupWrapper(
        chain: ChainModel,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel> {
        let dependency: (targetOperation: BaseOperation<String>, dependencies: [Operation])
        
        if chain.isEthereumBased {
            let wrapper = evmChainCorrespondingOperation(
                connection: connection,
                node: node,
                chain: chain
            )
            dependency = (
                targetOperation: wrapper.targetOperation,
                dependencies: wrapper.allOperations
            )
        } else {
            let operation = blockHashOperationFactory.createBlockHashOperation(
                connection: connection,
                for: { 0 }
            )
            dependency = (
                targetOperation: operation,
                dependencies: [operation]
            )
        }
        
        let chainSetupOperation = ClosureOperation<ChainModel> {
            let chainId = try dependency.targetOperation
                .extractNoCancellableResultData()
                .withoutHexPrefix()
            
            return chain.byChanging(chainId: chainId)
        }
        
        dependency.dependencies.forEach { operation in
            chainSetupOperation.addDependency(operation)
        }
        
        return CompoundOperationWrapper(
            targetOperation: chainSetupOperation,
            dependencies: dependency.dependencies
        )
    }
}

enum ChainType: Int {
    case substrate = 0
    case evm = 1
}

// MARK: Errors

enum CustomNetworkBaseInteractorError: Error {
    case alreadyExistRemote
    case alreadyExistCustom
    case invalidChainId
    case invalidNetworkType
    case connection(error: ConnectionFactoryError)
    case common(error: CommonError)
}
