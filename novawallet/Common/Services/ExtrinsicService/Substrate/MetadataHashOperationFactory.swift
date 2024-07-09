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
    let metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol

    let cache: InMemoryCache<ChainModel.Id, Data>

    init(
        metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.metadataRepositoryFactory = metadataRepositoryFactory
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
        let rawMetadataOperation = metadataRepositoryFactory.createRepository().fetchOperation(
            by: { chain.chainId },
            options: RepositoryFetchOptions()
        )

        let runtimeVersionOperation = createRuntimeVersionOperation(for: connection)

        let generateAndCacheOperation = ClosureOperation<Data?> {
            guard let rawMetadata = try rawMetadataOperation.extractNoCancellableResultData() else {
                throw CommonMetadataShortenerError.metadataMissing
            }

            let runtimeVersion = try runtimeVersionOperation.extractNoCancellableResultData()

            guard rawMetadata.version == runtimeVersion.specVersion else {
                throw CommonMetadataShortenerError.invalidMetadata(
                    localVersion: rawMetadata.version,
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
                metadata: rawMetadata.metadata,
                specVersion: runtimeVersion.specVersion,
                specName: runtimeVersion.specName,
                decimals: decimals,
                base58Prefix: chain.addressPrefix,
                tokenSymbol: utilityAsset.symbol
            )

            let newHash = try MetadataShortenerApi().generateMetadataHash(for: params)
            self.cache.store(value: newHash, for: chain.chainId)

            return newHash
        }

        generateAndCacheOperation.addDependency(runtimeVersionOperation)
        generateAndCacheOperation.addDependency(rawMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: generateAndCacheOperation,
            dependencies: [rawMetadataOperation, runtimeVersionOperation]
        )
    }
}

extension MetadataHashOperationFactory: MetadataHashOperationFactoryProtocol {
    func createCheckMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?> {
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
