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

enum ExtrinsicProofOperationFactoryError: Error {}

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
                throw CommonMetadataShortenerError.metadataMissing
            }

            let signatureParams = try signatureParamsClosure()

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

            let params = ExtrinsicProofParams(
                encodedCall: signatureParams.encodedCall,
                encodedSignedExtra: signatureParams.includedInExtrinsicExtra,
                encodedAdditionalSigned: signatureParams.includedInSignatureExtra,
                encodedMetadata: rawMetadata.metadata,
                specVersion: runtimeVersion.specVersion,
                specName: runtimeVersion.specName,
                decimals: decimals,
                base58Prefix: chain.addressPrefix.toSubstrateFormat(),
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
