import Foundation
import SubstrateSdk
import Operation_iOS

protocol CustomNetworkSetupTrait: NetworkNodeCorrespondingTrait {
    var operationQueue: OperationQueue { get }
}

extension CustomNetworkSetupTrait {
    func createSetupNetworkWrapper(
        partialChain: PartialCustomChainModel,
        rawRuntimeFetchFactory: RuntimeFetchOperationFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        typeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<ChainModel> {
        let fillPartialChainWrapper = createFillPartialChainWrapper(
            partialChain: partialChain,
            rawRuntimeFetchFactory: rawRuntimeFetchFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            typeRegistryFactory: typeRegistryFactory,
            connection: connection,
            node: node
        )
        
        let finishSetupOperation = ClosureOperation<ChainModel> {
            let filledPartialChain = try fillPartialChainWrapper
                .targetOperation
                .extractNoCancellableResultData()
            
            let finalChainModel = ChainModel(
                chainId: filledPartialChain.chainId,
                parentId: nil,
                name: filledPartialChain.name,
                assets: filledPartialChain.assets,
                nodes: filledPartialChain.nodes,
                nodeSwitchStrategy: filledPartialChain.nodeSwitchStrategy,
                addressPrefix: filledPartialChain.addressPrefix,
                types: nil,
                icon: filledPartialChain.iconUrl,
                options: filledPartialChain.options,
                externalApis: nil,
                explorers: [filledPartialChain.blockExplorer].compactMap { $0 },
                order: 0,
                additional: nil,
                syncMode: .full,
                source: .user,
                connectionMode: filledPartialChain.connectionMode
            )
            
            return finalChainModel
        }
        
        let dependencies = fillPartialChainWrapper.allOperations
        dependencies.forEach { finishSetupOperation.addDependency($0) }
        
        let wrapper = CompoundOperationWrapper(
            targetOperation: finishSetupOperation,
            dependencies: dependencies
        )
        
        return wrapper
    }
}

private extension CustomNetworkSetupTrait {
    func createFillPartialChainWrapper(
        partialChain: PartialCustomChainModel,
        rawRuntimeFetchFactory: RuntimeFetchOperationFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        typeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let chainIdSetupWrapper = createChainIdSetupWrapper(
            chain: partialChain,
            blockHashOperationFactory: blockHashOperationFactory,
            connection: connection,
            node: node
        )
        let typeSetupWrapper = createChainTypeOptionsWrapper(
            partialChainWrapper: chainIdSetupWrapper,
            rawRuntimeFetchFactory: rawRuntimeFetchFactory,
            typeRegistryFactory: typeRegistryFactory,
            connection: connection
        )
        let chainAssetSetupWrapper = createChainAssetSetupWrapper(
            partialChainWrapper: typeSetupWrapper,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connection: connection
        )
        
        return chainIdSetupWrapper
            .insertingHead(operations: typeSetupWrapper.allOperations + chainAssetSetupWrapper.dependencies)
            .insertingTail(operation: chainAssetSetupWrapper.targetOperation)
    }
    
    func createChainAssetSetupWrapper(
        partialChainWrapper: CompoundOperationWrapper<PartialCustomChainModel>,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let assetSetupWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let partialChain = try partialChainWrapper
                .targetOperation
                .extractNoCancellableResultData()
            
            return createMainAssetSetupWrapper(
                for: partialChain,
                systemPropertiesOperationFactory: systemPropertiesOperationFactory,
                connection: connection
            )
        }
        
        assetSetupWrapper.addDependency(wrapper: partialChainWrapper)
        
        return assetSetupWrapper
    }
    
    func createChainTypeOptionsWrapper(
        partialChainWrapper: CompoundOperationWrapper<PartialCustomChainModel>,
        rawRuntimeFetchFactory: RuntimeFetchOperationFactoryProtocol,
        typeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let typeSetupWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let partialChain = try partialChainWrapper
                .targetOperation
                .extractNoCancellableResultData()
            
            guard !partialChain.isEthereumBased else {
                return CompoundOperationWrapper.createWithResult(partialChain)
            }
            
            let rawRuntimeFetchWrapper = rawRuntimeFetchFactory.createMetadataFetchWrapper(
                for: partialChain.chainId,
                connection: connection
            )
            
            let typeSetupOperation = ClosureOperation<PartialCustomChainModel> {
                let rawRuntimeMedatada = try rawRuntimeFetchWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                
                let typeRegistrtryInfo = try typeRegistryFactory.createForMetadataAndDefaultTyping(
                    chain: partialChain,
                    runtimeMetadataItem: rawRuntimeMedatada
                )
                
                let ethereumBased = typeRegistrtryInfo
                    .typeRegistryCatalog
                    .nodeMatches(
                        closure: { ($0 as? FixedArrayNode)?.length == 20 },
                        typeName: "Address",
                        version: 0
                    )
                
                return ethereumBased
                    ? partialChain.adding([.ethereumBased])
                    : partialChain
            }
            
            typeSetupOperation.addDependency(rawRuntimeFetchWrapper.targetOperation)
            
            return CompoundOperationWrapper(
                targetOperation: typeSetupOperation,
                dependencies: rawRuntimeFetchWrapper.allOperations
            )
        }
        
        typeSetupWrapper.addDependency(wrapper: partialChainWrapper)
        
        return typeSetupWrapper
    }
    
    func createMainAssetSetupWrapper(
        for chain: PartialCustomChainModel,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let isEvmChain = chain.isEthereumBased && chain.noSubstrateRuntime
        
        return isEvmChain
            ? createEvmMainAssetSetupWrapper(for: chain)
            : createSubstrateMainAssetSetupWrapper(
                for: chain,
                systemPropertiesOperationFactory: systemPropertiesOperationFactory,
                connection: connection
            )
    }
    
    func createEvmMainAssetSetupWrapper(for chain: PartialCustomChainModel) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let defaultEVMAssetPrecision: UInt16 = 18
        
        return .createWithResult(
            chain.adding(
                AssetModel(
                    assetId: 0,
                    icon: nil,
                    name: chain.name,
                    symbol: chain.currencySymbol,
                    precision: defaultEVMAssetPrecision,
                    priceId: chain.mainAssetPriceId,
                    stakings: nil,
                    type: nil,
                    typeExtras: nil,
                    buyProviders: nil,
                    enabled: true,
                    source: .user
                )
            )
        )
    }
    
    func createSubstrateMainAssetSetupWrapper(
        for chain: PartialCustomChainModel,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let propertiesOperation = systemPropertiesOperationFactory.createSystemPropertiesOperation(connection: connection)
        
        let assetOperation = ClosureOperation<PartialCustomChainModel> {
            let properties = try propertiesOperation.extractNoCancellableResultData()
            
            guard let precision = properties.tokenDecimals.first else {
                throw CustomNetworkSetupError.decimalsNotFound
            }
            
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
            
            return chain
                .byChanging(addressPrefix: properties.ss58Format ?? properties.SS58Prefix)
                .adding(asset)
        }
        
        assetOperation.addDependency(propertiesOperation)
                
        return CompoundOperationWrapper(
            targetOperation: assetOperation,
            dependencies: [propertiesOperation]
        )
    }
    
    func createChainIdSetupWrapper(
        chain: PartialCustomChainModel,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        connection: ChainConnection,
        node: ChainNodeModel
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
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
        
        let chainSetupOperation = ClosureOperation<PartialCustomChainModel> {
            let chainId = try dependency
                .targetOperation
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

// MARK: Errors

enum CustomNetworkSetupError: Error {
    case decimalsNotFound
}
