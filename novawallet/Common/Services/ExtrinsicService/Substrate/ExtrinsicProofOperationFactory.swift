import Foundation
import MetadataShortenerApi
import SubstrateSdk
import Operation_iOS

protocol ExtrinsicProofOperationFactoryProtocol {
    func createExtrinsicProofWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        signatureParamsClosure: @escaping () throws -> ExtrinsicSignatureParams
    ) -> CompoundOperationWrapper<Data>
}

final class ExtrinsicProofOperationFactory {
    let metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol

    init(metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol) {
        self.metadataRepositoryFactory = metadataRepositoryFactory
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
}

extension ExtrinsicProofOperationFactory: ExtrinsicProofOperationFactoryProtocol {
    func createExtrinsicProofWrapper(
        for chain: ChainModel,
        connection: JSONRPCEngine,
        signatureParamsClosure: @escaping () throws -> ExtrinsicSignatureParams
    ) -> CompoundOperationWrapper<Data> {
        let rawMetadataOperation = metadataRepositoryFactory.createRepository().fetchOperation(
            by: { chain.chainId },
            options: RepositoryFetchOptions()
        )

        let runtimeVersionOperation = createRuntimeVersionOperation(for: connection)

        let fetchOperation = ClosureOperation<Data> {
            guard let rawMetadata = try rawMetadataOperation.extractNoCancellableResultData() else {
                throw CommonError.dataCorruption
            }

            let signatureParams = try signatureParamsClosure()

            let runtimeVersion = try runtimeVersionOperation.extractNoCancellableResultData()

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
                specVersion: runtimeVersion.specVersion,
                specName: runtimeVersion.specName,
                decimals: decimals,
                base58Prefix: chain.addressPrefix,
                tokenSymbol: utilityAsset.symbol
            )

            return try MetadataShortenerApi().generateExtrinsicProof(for: params)
        }

        fetchOperation.addDependency(runtimeVersionOperation)
        fetchOperation.addDependency(rawMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: fetchOperation,
            dependencies: [rawMetadataOperation, runtimeVersionOperation]
        )
    }
}
