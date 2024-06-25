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

    init(
        metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.metadataRepositoryFactory = metadataRepositoryFactory
        self.operationQueue = operationQueue
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

        let fetchOperation = ClosureOperation<Data?> {
            guard let rawMetadata = try rawMetadataOperation.extractNoCancellableResultData() else {
                throw CommonError.dataCorruption
            }

            let runtimeVersion = try runtimeVersionOperation.extractNoCancellableResultData()

            guard let utilityAsset = chain.utilityAsset() else {
                throw CommonError.dataCorruption
            }

            guard utilityAsset.decimalPrecision <= UInt8.max, utilityAsset.decimalPrecision >= 0 else {
                throw CommonError.dataCorruption
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

            return try MetadataShortenerApi().generateMetadataHash(for: params)
        }

        fetchOperation.addDependency(runtimeVersionOperation)
        fetchOperation.addDependency(rawMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: fetchOperation,
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
