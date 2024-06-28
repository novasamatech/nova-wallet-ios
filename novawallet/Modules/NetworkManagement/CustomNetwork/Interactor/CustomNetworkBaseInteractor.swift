import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait, NetworkNodeConnectingTrait, NetworkNodeCorrespondingTrait {
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
        
        connect(
            to: node,
            chain: partialChain,
            urlPredicate: NSPredicate.ws
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
    func connect(
        to node: ChainNodeModel,
        chain: ChainModel,
        urlPredicate: NSPredicate
    ) {
        do {
            try connect(
                to: node,
                replacing: nil,
                chain: chain,
                urlPredicate: urlPredicate
            )
        } catch NetworkNodeConnectingError.alreadyExists(let existingNode, let existingChain) {
            if existingChain.source == .user {
                basePresenter?.didReceive(
                    .alreadyExistCustom(
                        node: existingNode,
                        chain: existingChain
                    )
                )
            } else {
                basePresenter?.didReceive(
                    .alreadyExistRemote(
                        node: existingNode,
                        chain: existingChain
                    )
                )
            }
        } catch is NetworkNodeCorrespondingError {
            basePresenter?.didReceive(.invalidChainId)
        } catch NetworkNodeConnectingError.wrongFormat {
            basePresenter?.didReceive(
                .wrongNodeUrlFormat(innerError: .wrongFormat)
            )
        } catch {
            basePresenter?.didReceive(
                .common(innerError: .undefined)
            )
        }
    }
    
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
    case alreadyExistRemote(node: ChainNodeModel, chain: ChainModel)
    case alreadyExistCustom(node: ChainNodeModel, chain: ChainModel)
    case invalidChainId
    case invalidNetworkType(selectedType: ChainType)
    case wrongNodeUrlFormat(innerError: NetworkNodeConnectingError)
    case common(innerError: CommonError)
}

extension CustomNetworkBaseInteractorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case let .alreadyExistRemote(_, chain):
                .init(
                    title: R.string.localizable.networkAddAlertAlreadyExistsTitle(
                        preferredLanguages: locale?.rLanguages
                    ),
                    message: R.string.localizable.networkAddAlertAlreadyExistsRemoteMessage(
                        chain.name,
                        preferredLanguages: locale?.rLanguages
                    )
                )
        case let .alreadyExistCustom(_, chain):
                .init(
                    title: R.string.localizable.networkAddAlertAlreadyExistsTitle(
                        preferredLanguages: locale?.rLanguages
                    ),
                    message: R.string.localizable.networkAddAlertAlreadyExistsCustomMessage(
                        chain.name,
                        preferredLanguages: locale?.rLanguages
                    )
                )
        case .invalidChainId:
                .init(
                    title: R.string.localizable.networkAddAlertInvalidChainIdTitle(
                        preferredLanguages: locale?.rLanguages
                    ),
                    message: R.string.localizable.networkAddAlertInvalidChainIdMessage(
                        preferredLanguages: locale?.rLanguages
                    )
                )
        case let .invalidNetworkType(selectedType):
                .init(
                    title: R.string.localizable.networkAddAlertInvalidNetworkTypeTitle(
                        preferredLanguages: locale?.rLanguages
                    ),
                    message: R.string.localizable.networkAddAlertInvalidNetworkTypeMessage(
                        selectedType == .evm ? "Substrate" : "EVM",
                        preferredLanguages: locale?.rLanguages
                    )
                )
        case let .wrongNodeUrlFormat(innerError):
            innerError.toErrorContent(for: locale)
        case let .common(innerError): 
            innerError.toErrorContent(for: locale)
        }
    }
}
