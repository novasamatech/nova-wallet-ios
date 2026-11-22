import Foundation
import MetadataShortenerApi
import SubstrateSdk
import Operation_iOS

protocol MetadataHashOperationFactoryProtocol {
    func createCheckMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?>
}

final class MetadataHashOperationFactory {
    let operationQueue: OperationQueue
    let sourceProvider: MetadataHashSourceProviding

    let cache: InMemoryCache<ChainModel.Id, Data>

    init(
        sourceProvider: MetadataHashSourceProviding,
        operationQueue: OperationQueue
    ) {
        self.sourceProvider = sourceProvider
        self.operationQueue = operationQueue
        cache = InMemoryCache()
    }

    private func createRuntimeVersionOperation(
        for connection: JSONRPCEngine
    ) -> BaseOperation<RuntimeVersionFull> {
        JSONRPCOperation<[String], RuntimeVersionFull>(
            engine: connection,
            method: RPCMethod.getRuntimeVersion,
            timeout: JSONRPCTimeout.hour
        )
    }

    private func createFetchMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Data?> {
        let sourceWrapper = sourceProvider.createFetchWrapper(for: chain.chainId, connection: connection)

        let runtimeVersionOperation = createRuntimeVersionOperation(for: connection)

        let generateAndCacheOperation = ClosureOperation<Data?> {
            // the hash can't exist without the metadata it is defined over: as for a runtime with metadata v14
            guard let source = try sourceWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            let runtimeVersion = try runtimeVersionOperation.extractNoCancellableResultData()

            guard source.specVersion == runtimeVersion.specVersion else {
                throw CommonMetadataShortenerError.invalidMetadata(
                    localVersion: source.specVersion,
                    remoteVersion: runtimeVersion.specVersion
                )
            }

            guard let utilityAsset = chain.utilityAsset() else {
                throw CommonMetadataShortenerError.missingNativeAsset
            }

            guard utilityAsset.decimalPrecision <= UInt8.max, utilityAsset.decimalPrecision >= 0 else {
                throw CommonMetadataShortenerError.invalidDecimals
            }

            let decimals = UInt8(utilityAsset.decimalPrecision)

            let params = MetadataHashParams(
                metadata: source.metadata,
                specVersion: runtimeVersion.specVersion,
                specName: runtimeVersion.specName,
                decimals: decimals,
                base58Prefix: chain.addressPrefix.toSubstrateFormat(),
                tokenSymbol: utilityAsset.symbol
            )

            let newHash = try MetadataShortenerApi().generateMetadataHash(for: params)
            self.cache.store(value: newHash, for: chain.chainId)

            return newHash
        }

        generateAndCacheOperation.addDependency(runtimeVersionOperation)
        generateAndCacheOperation.addDependency(sourceWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: generateAndCacheOperation,
            dependencies: sourceWrapper.allOperations + [runtimeVersionOperation]
        )
    }
}

extension MetadataHashOperationFactory: MetadataHashOperationFactoryProtocol {
    func createCheckMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?> {
        guard !chain.disabledCheckMetadataHash else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        if let existingHash = cache.fetchValue(for: chain.chainId) {
            return CompoundOperationWrapper.createWithResult(existingHash)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<Data?> = OperationCombiningService.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard codingFactory.supportsMetadataHash() else {
                return nil
            }

            return self.createFetchMetadataHashWrapper(
                for: chain,
                connection: connection
            )
        }

        wrapper.addDependency(operations: [codingFactoryOperation])

        return wrapper.insertingHead(operations: [codingFactoryOperation])
    }
}
