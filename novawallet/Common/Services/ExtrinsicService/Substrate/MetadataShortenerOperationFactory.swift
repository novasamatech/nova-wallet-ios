import Foundation
import MetadataShortenerApi
import SubstrateSdk
import Operation_iOS

protocol MetadataShortenerOperationFactoryProtocol {
    func createCheckMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Data?>

    func createExtrinsicProofWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        signatureParamsClosure: @escaping () throws -> ExtrinsicSignatureParams
    ) -> CompoundOperationWrapper<Data>
}

final class MetadataShortenerOperationFactory {
    let operationQueue: OperationQueue
    let metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol

    init(
        metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.metadataRepositoryFactory = metadataRepositoryFactory
        self.operationQueue = operationQueue
    }
    
    private func fetchRuntimeVersionOperation(
        for connection: JSONRPCEngine
    ) -> BaseOperation<RuntimeVersionFull> {
        let operation = JSONRPCOperation(
            engine: connection,
            method: RPCMethod.getRuntimeVersion,
            parameters: nil,
            timeout: JSONRPCTimeout.hour
        )
    }

    private func createFetchMetadataHashWrapper(
        for chain: ChainModel,
        connection _: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data?> {
        let rawMetadataOperation = metadataRepositoryFactory.createRepository().fetchOperation(
            by: { chain.chainId },
            options: RepositoryFetchOptions()
        )

        let fetchOperation = ClosureOperation<Data?> {
            guard let rawMetadata = try rawMetadataOperation.extractNoCancellableResultData() else {
                throw CommonError.dataCorruption
            }

            guard let utilityAsset = chain.utilityAsset() else {
                throw CommonError.dataCorruption
            }

            guard utilityAsset.decimalPrecision <= UInt8.max, utilityAsset.decimalPrecision >= 0 else {
                throw CommonError.dataCorruption
            }

            let decimals = UInt8(utilityAsset.decimalPrecision)

            let params = MetadataHashParams(
                metadata: rawMetadata.metadata,
                specVersion: codingFactory.specVersion,
                specName: "",
                decimals: decimals,
                base58Prefix: chain.addressPrefix,
                tokenSymbol: utilityAsset.symbol
            )

            return try MetadataShortenerApi().generateMetadataHash(for: params)
        }

        fetchOperation.addDependency(rawMetadataOperation)

        return CompoundOperationWrapper(targetOperation: fetchOperation, dependencies: [rawMetadataOperation])
    }
}

extension MetadataShortenerOperationFactory: MetadataShortenerOperationFactoryProtocol {
    func createCheckMetadataHashWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
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
                connection: connection,
                codingFactory: codingFactory
            )
        }

        return wrapper.insertingHead(operations: [codingFactoryOperation])
    }

    func createExtrinsicProofWrapper(
        for chain: ChainModel,
        connection _: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        signatureParamsClosure: @escaping () throws -> ExtrinsicSignatureParams
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let rawMetadataOperation = metadataRepositoryFactory.createRepository().fetchOperation(
            by: { chain.chainId },
            options: RepositoryFetchOptions()
        )

        let fetchOperation = ClosureOperation<Data> {
            guard let rawMetadata = try rawMetadataOperation.extractNoCancellableResultData() else {
                throw CommonError.dataCorruption
            }

            let signatureParams = try signatureParamsClosure()

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let utilityAsset = chain.utilityAsset() else {
                throw CommonError.dataCorruption
            }

            guard utilityAsset.decimalPrecision <= UInt8.max, utilityAsset.decimalPrecision >= 0 else {
                throw CommonError.dataCorruption
            }

            let decimals = UInt8(utilityAsset.decimalPrecision)

            let params = ExtrinsicProofParams(
                encodedCall: signatureParams.encodedCall,
                encodedSignedExtra: signatureParams.includedInExtrinsicExtra,
                encodedAdditionalSigned: signatureParams.includedInSignatureExtra,
                encodedMetadata: rawMetadata.metadata,
                specVersion: codingFactory.specVersion,
                specName: "",
                decimals: decimals,
                base58Prefix: chain.addressPrefix,
                tokenSymbol: utilityAsset.symbol
            )

            return try MetadataShortenerApi().generateExtrinsicProof(for: params)
        }

        fetchOperation.addDependency(codingFactoryOperation)
        fetchOperation.addDependency(rawMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: fetchOperation,
            dependencies: [codingFactoryOperation, rawMetadataOperation]
        )
    }
}
