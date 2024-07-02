import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait, 
                                   NetworkNodeConnectingTrait,
                                   NetworkNodeCorrespondingTrait {
    weak var basePresenter: CustomNetworkBaseInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    
    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?
    
    private var partialChain: PartialCustomChainModel?
    
    init(
        chainRegistry: ChainRegistryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.blockHashOperationFactory = blockHashOperationFactory
        self.systemPropertiesOperationFactory = systemPropertiesOperationFactory
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.operationQueue = operationQueue
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
            name: Constants.defaultCustomNodeName,
            for: nil
        )
        
        let explorer = createExplorer(from: blockExplorerURL)
        let mainAssetPriceId = extractPriceId(from: coingeckoURL)
        let options: [LocalChainOptions]? = networkType == .evm ? [.ethereumBased] : nil
        
        let partialChain = PartialCustomChainModel(
            chainId: "",
            url: url,
            name: name, 
            assets: Set(),
            nodes: [node],
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: .roundRobin,
            addressPrefix: evmChainId ?? 0,
            connectionMode: .autoBalanced,
            blockExplorer: explorer,
            mainAssetPriceId: mainAssetPriceId
        )
        
        self.partialChain = partialChain
        
        connect(
            to: node,
            chain: partialChain,
            urlPredicate: NSPredicate.ws
        )
    }
    
    // MARK: To Override
    
    func handleSetupFinished(for network: ChainModel) {
        fatalError("Must be overriden by subclass")
    }
    
    func completeSetup() {
        fatalError("Must be overriden by subclass")
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
        handleWebSocketChangeState(
            connection,
            from: oldState,
            to: newState
        )
    }
}

// MARK: Private

private extension CustomNetworkBaseInteractor {
    
    // MARK: Connection
    
    func connect(
        to node: ChainNodeModel,
        chain: ChainNodeConnectable,
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
                .connecting(innerError: .wrongFormat)
            )
        } catch {
            basePresenter?.didReceive(
                .common(innerError: .undefined)
            )
        }
    }
    
    func handleWebSocketChangeState(
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
                self.basePresenter?.didReceive(
                    .connecting(innerError: .unableToConnect(networkName: chain.name))
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
    
    func handleConnected(
        connection: ChainConnection,
        chain: PartialCustomChainModel,
        node: ChainNodeModel
    ) {
        let finishSetupWrapper = finishChainSetupWrapper(
            partialChain: chain,
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
            case .failure:
                self?.basePresenter?.didReceive(.common(innerError: .undefined))
            }
        }
    }
    
    // MARK: Setup chain wrappers
    
    func finishChainSetupWrapper(
        partialChain: PartialCustomChainModel,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel> {
        let chainIdSetupWrapper = createChainIdFetchWrapper(
            chain: partialChain,
            connection: connection,
            node: node
        )
        
        let chainAssetSetupWrapper = createMainAssetSetupWrapper(
            for: partialChain,
            connection: connection
        )
        
        let finishSetupOperation = ClosureOperation<ChainModel> {
            let chainId = try chainIdSetupWrapper
                .targetOperation
                .extractNoCancellableResultData()
            
            let filledPartialChain = try chainAssetSetupWrapper
                .targetOperation
                .extractNoCancellableResultData()
            
            let finalChainModel = ChainModel(
                chainId: chainId,
                parentId: nil,
                name: filledPartialChain.name,
                assets: filledPartialChain.assets,
                nodes: filledPartialChain.nodes,
                nodeSwitchStrategy: filledPartialChain.nodeSwitchStrategy,
                addressPrefix: filledPartialChain.addressPrefix,
                types: nil,
                icon: nil,
                options: filledPartialChain.options,
                externalApis: nil,
                explorers: [filledPartialChain.blockExplorer].compactMap { $0 },
                order: 0,
                additional: nil,
                syncMode: .disabled,
                source: .user,
                connectionMode: filledPartialChain.connectionMode
            )
            
            return finalChainModel
        }
        
        let dependencies = chainIdSetupWrapper.allOperations + chainAssetSetupWrapper.allOperations
        dependencies.forEach { finishSetupOperation.addDependency($0) }
        
        let wrapper = CompoundOperationWrapper(
            targetOperation: finishSetupOperation,
            dependencies: dependencies
        )
        
        return wrapper
    }
    
    func createMainAssetSetupWrapper(
        for chain: PartialCustomChainModel,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let propertiesOperation: BaseOperation<SystemProperties>? = chain.isEthereumBased && chain.noSubstrateRuntime
            ? nil
            : systemPropertiesOperationFactory.createSystemPropertiesOperation(connection: connection)
        
        let assetOperation = ClosureOperation<PartialCustomChainModel> {
            let properties = try propertiesOperation?.extractNoCancellableResultData()
            let precision = properties?.tokenDecimals.first ?? Constants.defaultEVMAssetPrecision
            
            let asset = AssetModel(
                assetId: 0,
                icon: nil,
                name: chain.name,
                symbol: chain.currencySymbol,
                precision: precision,
                priceId: chain.mainAssetPriceId,
                stakings: nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil,
                enabled: true,
                source: .user
            )
            
            let updatedChain = if let properties {
                chain.byChanging(addressPrefix: properties.ss58Format ?? properties.SS58Prefix)
            } else {
                chain
            }
            
            return updatedChain.adding(asset)
        }
        
        let dependencies = [propertiesOperation].compactMap { $0 }
        
        dependencies.forEach { assetOperation.addDependency($0) }
                
        return CompoundOperationWrapper(
            targetOperation: assetOperation,
            dependencies: dependencies
        )
    }
    
    func createChainIdFetchWrapper(
        chain: ChainNodeConnectable,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel.Id> {
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
        
        let chainSetupOperation = ClosureOperation<ChainModel.Id> {
            let chainId = try dependency
                .targetOperation
                .extractNoCancellableResultData()
                .withoutHexPrefix()
            
            return chainId
        }
        
        dependency.dependencies.forEach { operation in
            chainSetupOperation.addDependency(operation)
        }
        
        return CompoundOperationWrapper(
            targetOperation: chainSetupOperation,
            dependencies: dependency.dependencies
        )
    }
    
    // MARK: Optional helpers
    
    func extractPriceId(from coingeckoUrlTemplate: String?) -> AssetModel.PriceId? {
        guard let coingeckoUrlTemplate else { return nil }
        
        let regex = try? NSRegularExpression(pattern: Constants.priceIdSearchRegexPattern)
        let range = NSRange(location: 0, length: coingeckoUrlTemplate.utf16.count)
        
        guard
            let match = regex?.firstMatch(in: coingeckoUrlTemplate, options: [], range: range),
            let matchedRange = Range(match.range(at: 1), in: coingeckoUrlTemplate)
        else {
            return nil
        }
                
        return String(coingeckoUrlTemplate[matchedRange])
    }
    
    func createExplorer(from url: String?) -> ChainModel.Explorer? {
        guard let url = url?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) else {
            return nil
        }
        
        let namedTemplate: NamedUrlTemplate? = if checkExplorer(urlString: url, with: .subscan) {
            (Constants.subscan, [url, Constants.subscanTemplatePath].joined(with: .slash))
        } else if checkExplorer(urlString: url, with: .statescan) {
            (Constants.statescan, [url, Constants.statescanTemplatePath].joined(with: .slash))
        } else if checkExplorer(urlString: url, with: .etherscan) {
            (Constants.etherscan, Constants.etherscanTemplate)
        } else {
            nil
        }
        
        guard
            let name = namedTemplate?.name,
            let template = namedTemplate?.template
        else {
            return nil
        }
        
        let explorer = ChainModel.Explorer(
            name: name,
            account: nil,
            extrinsic: template,
            event: nil
        )
        
        return explorer
    }
    
    func checkExplorer(
        urlString: String,
        with pattern: BlockExplorerPatterns
    ) -> Bool {
        let regex = try? NSRegularExpression(
            pattern: pattern.rawValue,
            options: .caseInsensitive
        )
        
        let range = NSRange(location: 0, length: urlString.utf16.count)
        if let match = regex?.firstMatch(in: urlString, options: [], range: range) {
            return match.range.length == urlString.utf16.count
        } else {
            return false
        }
    }
}

// MARK: Constants

private extension CustomNetworkBaseInteractor {
    enum Constants {
        static let subscan = "Subscan"
        static let subscanTemplatePath = "extrinsic/{hash}"
        
        static let statescan = "Statescan"
        static let statescanTemplatePath = "extrinsic/{hash}"
        
        static let etherscan = "Etherscan"
        static let etherscanTemplate = "https://etherscan.io/tx/{hash}"
        
        static let defaultCustomNodeName = "My custom node"
        
        static let defaultEVMAssetPrecision: UInt16 = 18
        
        static let priceIdSearchRegexPattern = "\\{([^}]*)\\}"
    }
}

// MARK: Regex patterns

private extension CustomNetworkBaseInteractor {
    enum BlockExplorerPatterns: String {
        case subscan = #"^https:\/\/([a-zA-Z0-9-]+\.)*subscan\.io$"#
        case statescan = #"^https:\/\/([a-zA-Z0-9-]+\.)*statescan\.io$"#
        case etherscan = #"etherscan"#
    }
}

// MARK: DTO

private extension CustomNetworkBaseInteractor {
    struct PartialCustomChainModel: ChainNodeConnectable {
        let chainId: String
        let url: String
        let name: String
        let assets: Set<AssetModel>
        let nodes: Set<ChainNodeModel>
        let currencySymbol: String
        let options: [LocalChainOptions]?
        let nodeSwitchStrategy: ChainModel.NodeSwitchStrategy
        let addressPrefix: UInt16
        let connectionMode: ChainModel.ConnectionMode
        let blockExplorer: ChainModel.Explorer?
        let mainAssetPriceId: AssetModel.PriceId?
        
        func adding(_ asset: AssetModel) -> PartialCustomChainModel {
            PartialCustomChainModel(
                chainId: chainId,
                url: url,
                name: name,
                assets: assets.union([asset]), 
                nodes: nodes,
                currencySymbol: currencySymbol,
                options: options,
                nodeSwitchStrategy: nodeSwitchStrategy,
                addressPrefix: addressPrefix,
                connectionMode: connectionMode,
                blockExplorer: blockExplorer,
                mainAssetPriceId: mainAssetPriceId
            )
        }
        
        func byChanging(addressPrefix: UInt16?) -> PartialCustomChainModel {
            PartialCustomChainModel(
                chainId: chainId,
                url: url,
                name: name,
                assets: assets, 
                nodes: nodes,
                currencySymbol: currencySymbol,
                options: options,
                nodeSwitchStrategy: nodeSwitchStrategy,
                addressPrefix: addressPrefix ?? self.addressPrefix,
                connectionMode: connectionMode,
                blockExplorer: blockExplorer,
                mainAssetPriceId: mainAssetPriceId
            )
        }
    }
}

enum ChainType: Int {
    case substrate = 0
    case evm = 1
}
