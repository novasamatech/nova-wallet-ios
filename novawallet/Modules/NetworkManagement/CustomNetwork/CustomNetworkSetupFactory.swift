import Foundation
import SubstrateSdk
import Operation_iOS

enum CustomNetworkSetupOperationType {
    case full
    case noRuntime
}

protocol CustomNetworkSetupFactoryProtocol {
    func createOperation(
        with partialChain: PartialCustomChainModel,
        connection: ChainConnection,
        node: ChainNodeModel,
        type: CustomNetworkSetupOperationType
    ) -> CompoundOperationWrapper<ChainModel>
}

class CustomNetworkSetupFactory: NetworkNodeCorrespondingTrait {
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol

    private let rawRuntimeFetchFactory: RuntimeFetchOperationFactoryProtocol
    private let systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol
    private let chainNameOperationFactory: ChainNameOperationFactoryProtocol
    private let typeRegistryFactory: RuntimeTypeRegistryFactoryProtocol

    private let operationQueue: OperationQueue

    init(
        rawRuntimeFetchFactory: RuntimeFetchOperationFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        chainNameOperationFactory: ChainNameOperationFactoryProtocol,
        typeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.rawRuntimeFetchFactory = rawRuntimeFetchFactory
        self.blockHashOperationFactory = blockHashOperationFactory
        self.systemPropertiesOperationFactory = systemPropertiesOperationFactory
        self.chainNameOperationFactory = chainNameOperationFactory
        self.typeRegistryFactory = typeRegistryFactory
        self.operationQueue = operationQueue
    }
}

extension CustomNetworkSetupFactory: CustomNetworkSetupFactoryProtocol {
    func createOperation(
        with partialChain: PartialCustomChainModel,
        connection: ChainConnection,
        node: ChainNodeModel,
        type: CustomNetworkSetupOperationType
    ) -> CompoundOperationWrapper<ChainModel> {
        let fillPartialChainWrapper = createFillPartialChainWrapper(
            partialChain: partialChain,
            connection: connection,
            node: node,
            type: type
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
                legacyAddressPrefix: nil,
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

private extension CustomNetworkSetupFactory {
    func createFillPartialChainWrapper(
        partialChain: PartialCustomChainModel,
        connection: ChainConnection,
        node: ChainNodeModel,
        type: CustomNetworkSetupOperationType
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let chainIdSetupWrapper = createChainIdSetupWrapper(
            chain: partialChain,
            blockHashOperationFactory: blockHashOperationFactory,
            connection: connection,
            node: node
        )

        let variableWrapper = switch type {
        case .noRuntime:
            createChainNameSetupWrapper(
                partialChainWrapper: chainIdSetupWrapper,
                chainNameOperationFactory: chainNameOperationFactory,
                connection: connection
            )
        case .full:
            createChainTypeOptionsWrapper(
                partialChainWrapper: chainIdSetupWrapper,
                rawRuntimeFetchFactory: rawRuntimeFetchFactory,
                typeRegistryFactory: typeRegistryFactory,
                connection: connection
            )
        }

        let chainAssetSetupWrapper = createChainAssetSetupWrapper(
            partialChainWrapper: variableWrapper,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connection: connection
        )

        return chainIdSetupWrapper
            .insertingHead(operations: variableWrapper.allOperations + chainAssetSetupWrapper.dependencies)
            .insertingTail(operation: chainAssetSetupWrapper.targetOperation)
    }

    func createChainAssetSetupWrapper(
        partialChainWrapper: CompoundOperationWrapper<PartialCustomChainModel>,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let assetSetupWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            let partialChain = try partialChainWrapper
                .targetOperation
                .extractNoCancellableResultData()

            guard let resultWrapper = self?.createMainAssetSetupWrapper(
                for: partialChain,
                systemPropertiesOperationFactory: systemPropertiesOperationFactory,
                connection: connection
            ) else {
                return .createWithResult(partialChain)
            }

            return resultWrapper
        }

        assetSetupWrapper.addDependency(wrapper: partialChainWrapper)

        return assetSetupWrapper
    }

    func createChainNameSetupWrapper(
        partialChainWrapper: CompoundOperationWrapper<PartialCustomChainModel>,
        chainNameOperationFactory: ChainNameOperationFactoryProtocol,
        connection: ChainConnection
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let chainNameSetupWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let partialChain = try partialChainWrapper
                .targetOperation
                .extractNoCancellableResultData()

            guard partialChain.hasSubstrateRuntime else {
                return CompoundOperationWrapper.createWithResult(partialChain)
            }

            let chainNameOperation = chainNameOperationFactory.createChainNameOperation(connection: connection)

            let chainSetupOperation = ClosureOperation<PartialCustomChainModel> {
                let chainName = try chainNameOperation.extractNoCancellableResultData()

                return partialChain.byChanging(name: chainName)
            }

            chainSetupOperation.addDependency(chainNameOperation)

            return CompoundOperationWrapper(
                targetOperation: chainSetupOperation,
                dependencies: [chainNameOperation]
            )
        }

        chainNameSetupWrapper.addDependency(wrapper: partialChainWrapper)

        return chainNameSetupWrapper
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

            guard partialChain.hasSubstrateRuntime else {
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
        chain.isPureEvm
            ? createEvmMainAssetSetupWrapper(for: chain)
            : createSubstrateMainAssetSetupWrapper(
                for: chain,
                systemPropertiesOperationFactory: systemPropertiesOperationFactory,
                connection: connection
            )
    }

    func createEvmMainAssetSetupWrapper(
        for chain: PartialCustomChainModel
    ) -> CompoundOperationWrapper<PartialCustomChainModel> {
        let defaultEVMAssetPrecision: UInt16 = 18

        return .createWithResult(
            chain.adding(
                AssetModel(
                    assetId: 0,
                    icon: nil,
                    name: chain.name,
                    symbol: chain.currencySymbol ?? "ETH",
                    precision: defaultEVMAssetPrecision,
                    priceId: chain.mainAssetPriceId,
                    stakings: nil,
                    type: AssetType.evmNative.rawValue,
                    typeExtras: nil,
                    buyProviders: nil,
                    sellProviders: nil,
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
        let propertiesOperation = systemPropertiesOperationFactory.createSystemPropertiesOperation(
            connection: connection
        )

        let assetOperation = ClosureOperation<PartialCustomChainModel> {
            let properties = try propertiesOperation.extractNoCancellableResultData()

            guard let precision = properties.tokenDecimals.first else {
                throw CustomNetworkSetupError.decimalsNotFound
            }

            guard let networkMainAssetSymbol = properties.tokenSymbol.first else {
                throw CommonError.noDataRetrieved
            }

            if let enteredSymbol = chain.currencySymbol {
                guard networkMainAssetSymbol == enteredSymbol else {
                    throw CustomNetworkSetupError.wrongCurrencySymbol(
                        enteredSymbol: enteredSymbol,
                        actualSymbol: networkMainAssetSymbol
                    )
                }
            }

            let asset = AssetModel(
                assetId: 0,
                icon: nil,
                name: chain.name,
                symbol: networkMainAssetSymbol,
                precision: precision,
                priceId: chain.mainAssetPriceId,
                stakings: nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil,
                sellProviders: nil,
                enabled: true,
                source: .user
            )

            let addressPrefix: UInt64? = if let ss58Format = properties.ss58Format {
                UInt64(ss58Format)
            } else if let SS58Prefix = properties.SS58Prefix {
                UInt64(SS58Prefix)
            } else {
                nil
            }

            return chain
                .byChanging(addressPrefix: addressPrefix)
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

        if chain.isPureEvm {
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
            do {
                let chainId = try dependency
                    .targetOperation
                    .extractNoCancellableResultData()
                    .withoutHexPrefix()

                return chain.byChanging(chainId: chainId)
            } catch {
                if error is NetworkNodeCorrespondingError {
                    throw (error)
                } else {
                    throw (CustomNetworkSetupError.chainIdObtainFailed(ethereumBased: chain.isEthereumBased))
                }
            }
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

enum CustomNetworkSetupError: Error, Hashable {
    case decimalsNotFound
    case wrongCurrencySymbol(enteredSymbol: String, actualSymbol: String)
    case chainIdObtainFailed(ethereumBased: Bool)
}
