import Foundation
import SubstrateSdk
import Operation_iOS

struct DAppExtrinsicRawSignatureResult {
    let sender: ExtrinsicSenderResolution
    let signature: Data
    let modifiedExtrinsic: Data?
}

struct DAppExtrinsicRawExtrinsicResult {
    let sender: ExtrinsicSenderResolution
    let signedExtrinsic: Data
}

final class DAppExtrinsicBuilderOperationFactory {
    struct ExtrinsicSenderBuilderResult {
        let sender: ExtrinsicSenderResolution
        let builder: ExtrinsicBuilderProtocol
        let modifiedOriginalExtrinsic: Bool
    }

    struct MetadataHashResult {
        let modifiedOriginal: Bool
        let metadataHash: Data?
    }

    let processedResult: DAppOperationProcessedResult
    let chain: ChainModel
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let feeRegistry: ExtrinsicFeeEstimationRegistring
    let metadataHashOperationFactory: MetadataHashOperationFactoryProtocol

    init(
        processedResult: DAppOperationProcessedResult,
        chain: ChainModel,
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        feeRegistry: ExtrinsicFeeEstimationRegistring,
        metadataHashOperationFactory: MetadataHashOperationFactoryProtocol
    ) {
        self.chain = chain
        self.processedResult = processedResult
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.feeRegistry = feeRegistry
        self.metadataHashOperationFactory = metadataHashOperationFactory
    }

    private func createExtrinsicBuilderResultOperation(
        from result: DAppOperationProcessedResult,
        metadataHashOperation: BaseOperation<MetadataHashResult>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        feeInstallerOperation: BaseOperation<ExtrinsicFeeInstalling>?
    ) -> BaseOperation<ExtrinsicSenderBuilderResult> {
        ClosureOperation<ExtrinsicSenderBuilderResult> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let metadataHashResult = try metadataHashOperation.extractNoCancellableResultData()
            let feeInstaller = try feeInstallerOperation?.extractNoCancellableResultData()

            let extrinsic = result.extrinsic

            // DApp signing currently doesn't allow to modify extrinsic
            let sender = ExtrinsicSenderResolution.current(result.account)

            let address = MultiAddress.accoundId(sender.account.accountId)

            let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(
                for: result.account.chainId
            )

            let runtimeContext = codingFactory.createRuntimeJsonContext()

            var builder: ExtrinsicBuilderProtocol = try ExtrinsicBuilder(
                specVersion: extrinsic.specVersion,
                transactionVersion: extrinsic.transactionVersion,
                genesisHash: extrinsic.genesisHash
            )
            .with(signaturePayloadFormat: sender.account.type.signaturePayloadFormat)
            .with(runtimeJsonContext: runtimeContext)
            .with(address: address)
            .with(nonce: UInt32(extrinsic.nonce))
            .with(era: extrinsic.era, blockHash: extrinsic.blockHash)

            if let metadataHash = metadataHashResult.metadataHash {
                builder = builder.with(metadataHash: metadataHash)
            }

            for signedExtension in signedExtensionFactory.createExtensions() {
                builder = builder.adding(transactionExtension: signedExtension)
            }

            builder = try result.extrinsic.method.accept(builder: builder)

            if extrinsic.tip > 0 {
                builder = builder.with(tip: extrinsic.tip)
            }

            if let feeInstaller {
                builder = try feeInstaller.installingFeeSettings(
                    to: builder,
                    coderFactory: codingFactory
                )
            } else if let rawFeeAssetId = result.extrinsic.assetId {
                let txPayment = AssetConversionTxPayment(
                    tip: extrinsic.tip,
                    assetId: rawFeeAssetId
                )

                builder = builder.adding(transactionExtension: txPayment)
            }

            let isModifiedExtrinsic = metadataHashResult.modifiedOriginal

            return ExtrinsicSenderBuilderResult(
                sender: sender,
                builder: builder,
                modifiedOriginalExtrinsic: isModifiedExtrinsic
            )
        }
    }

    private func createActualMetadataHashWrapper(
        for result: DAppOperationProcessedResult,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<MetadataHashResult> {
        do {
            let optMetadataHash = try result.extrinsic.metadataHash.map { try Data(hexString: $0) }

            // If a dapp haven't declared a permission to modify extrinsic - return metadataHash from payload
            if !result.extrinsic.withSignedTransaction {
                return .createWithResult(
                    .init(
                        modifiedOriginal: false,
                        metadataHash: optMetadataHash
                    )
                )
            }

            // If a dapp have specified metadata hash explicitly - use it
            if let metadataHash = optMetadataHash {
                return .createWithResult(
                    .init(
                        modifiedOriginal: false,
                        metadataHash: metadataHash
                    )
                )
            }

            let metadataHashWrapper = metadataHashOperationFactory.createCheckMetadataHashWrapper(
                for: chain,
                connection: connection,
                runtimeProvider: runtimeProvider
            )

            let mappingOperation = ClosureOperation<MetadataHashResult> {
                let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData()

                return MetadataHashResult(modifiedOriginal: true, metadataHash: metadataHash)
            }

            mappingOperation.addDependency(metadataHashWrapper.targetOperation)

            return metadataHashWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }

    private func createBaseBuilderWrapper(
        for result: DAppOperationProcessedResult,
        feeAssetId: ChainAssetId?,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ExtrinsicSenderBuilderResult> {
        let metadataHashWrapper = createActualMetadataHashWrapper(
            for: processedResult,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        // don't install fee asset if no provided
        let feeInstallerWrapper: CompoundOperationWrapper<ExtrinsicFeeInstalling>? = if let feeAssetId {
            feeRegistry.createFeeInstallerWrapper(payingIn: feeAssetId) {
                result.account
            }
        } else {
            nil
        }

        let builderOperation = createExtrinsicBuilderResultOperation(
            from: result,
            metadataHashOperation: metadataHashWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            feeInstallerOperation: feeInstallerWrapper?.targetOperation
        )

        builderOperation.addDependency(metadataHashWrapper.targetOperation)
        builderOperation.addDependencyIfExists(feeInstallerWrapper?.targetOperation)

        return metadataHashWrapper
            .insertingHeadIfExists(operations: feeInstallerWrapper?.allOperations)
            .insertingTail(operation: builderOperation)
    }

    private func createRawSignatureOperation(
        for result: DAppOperationProcessedResult,
        feeAssetId: ChainAssetId?,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<DAppExtrinsicRawExtrinsicResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderWrapper = createBaseBuilderWrapper(
            for: result,
            feeAssetId: feeAssetId,
            codingFactoryOperation: codingFactoryOperation
        )

        builderWrapper.addDependency(operations: [codingFactoryOperation])

        let payloadOperation = ClosureOperation<DAppExtrinsicRawExtrinsicResult> {
            let builderResult = try builderWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let builder = builderResult.builder
            let context = ExtrinsicSigningContext.Substrate(
                senderResolution: builderResult.sender,
                extrinsicMemo: builder.makeMemo(),
                codingFactory: codingFactory
            )

            let signedExtrinsic = try builder.signing(
                with: { try signingClosure($0, $1) },
                context: context,
                codingFactory: codingFactory
            )
            .build(using: codingFactory, metadata: codingFactory.metadata)

            return DAppExtrinsicRawExtrinsicResult(sender: builderResult.sender, signedExtrinsic: signedExtrinsic)
        }

        payloadOperation.addDependency(codingFactoryOperation)
        payloadOperation.addDependency(builderWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: payloadOperation,
            dependencies: [codingFactoryOperation] + builderWrapper.allOperations
        )
    }
}

extension DAppExtrinsicBuilderOperationFactory: ExtrinsicBuilderOperationFactoryProtocol {
    func createWrapper(
        customClosure _: @escaping ExtrinsicBuilderIndexedClosure,
        indexes _: [Int],
        payingFeeIn feeAssetId: ChainAssetId?,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        let signatureWrapper = createRawSignatureOperation(
            for: processedResult,
            feeAssetId: feeAssetId,
            signingClosure: signingClosure
        )

        let mappingOperation = ClosureOperation<ExtrinsicsCreationResult> {
            let result = try signatureWrapper.targetOperation.extractNoCancellableResultData()

            return ExtrinsicsCreationResult(extrinsics: [result.signedExtrinsic], sender: result.sender)
        }

        mappingOperation.addDependency(signatureWrapper.targetOperation)

        let dependencies = signatureWrapper.allOperations

        let wrapper = CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)

        return wrapper
    }

    func createDummySigner(for cryptoType: MultiassetCryptoType) throws -> DummySigner {
        try DummySigner(cryptoType: cryptoType)
    }

    func createRawSignatureWrapper(
        payingFeeIn feeAssetId: ChainAssetId?,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<DAppExtrinsicRawSignatureResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderWrapper = createBaseBuilderWrapper(
            for: processedResult,
            feeAssetId: feeAssetId,
            codingFactoryOperation: codingFactoryOperation
        )

        builderWrapper.addDependency(operations: [codingFactoryOperation])

        let signOperation = ClosureOperation<DAppExtrinsicRawSignatureResult> {
            let builderResult = try builderWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let builder = builderResult.builder
            let context = ExtrinsicSigningContext.Substrate(
                senderResolution: builderResult.sender,
                extrinsicMemo: builder.makeMemo(),
                codingFactory: codingFactory
            )

            let rawSignature = try builder.buildRawSignature(
                using: { data in
                    try signingClosure(data, .substrateExtrinsic(context))
                },
                encodingFactory: codingFactory,
                metadata: codingFactory.metadata
            )

            let modifiedExtrinsic: Data? = if builderResult.modifiedOriginalExtrinsic {
                try builder.signing(
                    with: { _, _ in rawSignature },
                    context: context,
                    codingFactory: codingFactory
                ).build(using: codingFactory, metadata: codingFactory.metadata)
            } else {
                nil
            }

            return DAppExtrinsicRawSignatureResult(
                sender: builderResult.sender,
                signature: rawSignature,
                modifiedExtrinsic: modifiedExtrinsic
            )
        }

        signOperation.addDependency(builderWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + builderWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: signOperation, dependencies: dependencies)
    }
}
