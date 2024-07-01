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
    
    var partialChain: PartialCustomChainModel?
    
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
        
        let explorer = createExplorer(from: blockExplorerURL)
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
}

// MARK: Private

private extension CustomNetworkBaseInteractor {
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
            case let .failure(error):
                print(error)
            }
        }
    }
    
    func finishChainSetupWrapper(
        partialChain: PartialCustomChainModel,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel> {
        let chainIdSetupWrapper = createChainIdSetupWrapper(
            chain: partialChain,
            connection: connection,
            node: node
        )
        
        let chainAssetSetupWrapper = createMainAssetSetuptWrapper(
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
        
        let wrapper = CompoundOperationWrapper(targetOperation: finishSetupOperation)
        wrapper.addDependency(wrapper: chainIdSetupWrapper)
        
        return wrapper
    }
    
    func createMainAssetSetuptWrapper(
        for chain: PartialCustomChainModel,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let propertiesOperation: BaseOperation<SystemProperties>? = chain.isEthereumBased && chain.noSubstrateRuntime
            ? nil
            : systemPropertiesOperationFactory.createSystemPropertiesOperation(connection: connection)
        
        let assetOperation = ClosureOperation<PartialCustomChainModel> {
            let properties = try propertiesOperation?.extractNoCancellableResultData()
            
            let asset = AssetModel(
                assetId: 0,
                icon: nil,
                name: chain.name,
                symbol: chain.currencySymbol,
                precision: properties?.tokenDecimals[0] ?? 18,
                priceId: nil,
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
    
    func createChainIdSetupWrapper(
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
            return try dependency.targetOperation
                .extractNoCancellableResultData()
                .withoutHexPrefix()
        }
        
        dependency.dependencies.forEach { operation in
            chainSetupOperation.addDependency(operation)
        }
        
        return CompoundOperationWrapper(
            targetOperation: chainSetupOperation,
            dependencies: dependency.dependencies
        )
    }
    
    func createExplorer(from url: String?) -> ChainModel.Explorer? {
        guard 
            let url = url?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            checkSubscan(urlString: url)
        else {
            return nil
        }
        
        let path = "extrinsic/{hash}"
        
        let templateUrl = [
            url,
            path
        ].joined(with: .slash)
        
        let explorer = ChainModel.Explorer(
            name: "Subscan",
            account: nil,
            extrinsic: templateUrl,
            event: nil
        )
        
        return explorer
    }
    
    func checkSubscan(urlString: String) -> Bool {
        let pattern = #"^https:\/\/([a-zA-Z0-9-]+\.)*subscan\.io$"#
        
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        let range = NSRange(location: 0, length: urlString.utf16.count)
        if let match = regex?.firstMatch(in: urlString, options: [], range: range) {
            return match.range.length == urlString.utf16.count
        } else {
            return false
        }
    }
}

// MARK: DTO

extension CustomNetworkBaseInteractor {
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
        let coingeckoURL: String?
        
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
                coingeckoURL: coingeckoURL
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
                coingeckoURL: coingeckoURL
            )
        }
    }
}

enum ChainType: Int {
    case substrate = 0
    case evm = 1
}
