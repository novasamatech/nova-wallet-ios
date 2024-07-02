import Foundation
import SubstrateSdk
import Operation_iOS

struct DAppExtrinsicRawSignatureResult {
    let sender: ExtrinsicSenderResolution
    let signedExtrinsic: Data
}

final class DAppExtrinsicBuilderOperationFactory {
    struct ExtrinsicSenderBuilderResult {
        let sender: ExtrinsicSenderResolution
        let builder: ExtrinsicBuilderProtocol
    }

    let processedResult: DAppOperationProcessedResult
    let runtimeProvider: RuntimeCodingServiceProtocol

    init(
        processedResult: DAppOperationProcessedResult,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) {
        self.processedResult = processedResult
        self.runtimeProvider = runtimeProvider
    }

    private func createBaseBuilderWrapper(
        for result: DAppOperationProcessedResult,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ExtrinsicSenderBuilderResult> {
        let builderOperation = ClosureOperation<ExtrinsicSenderBuilderResult> {
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()

            let extrinsic = result.extrinsic

            // DApp signing currently doesn't allow to modify extrinsic
            let sender = ExtrinsicSenderResolution.current(result.account)

            let address = MultiAddress.accoundId(sender.account.accountId)

            let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(
                for: result.account.chainId
            )

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

            for signedExtension in signedExtensionFactory.createExtensions() {
                builder = builder.adding(extrinsicSignedExtension: signedExtension)
            }

            builder = try result.extrinsic.method.accept(builder: builder)

            if extrinsic.tip > 0 {
                builder = builder.with(tip: extrinsic.tip)
            }

            return ExtrinsicSenderBuilderResult(sender: sender, builder: builder)
        }

        return CompoundOperationWrapper(targetOperation: builderOperation)
    }

    private func createRawSignatureOperation(
        for result: DAppOperationProcessedResult,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<DAppExtrinsicRawSignatureResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderWrapper = createBaseBuilderWrapper(
            for: result,
            codingFactoryOperation: codingFactoryOperation
        )

        builderWrapper.addDependency(operations: [codingFactoryOperation])

        let payloadOperation = ClosureOperation<DAppExtrinsicRawSignatureResult> {
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
            .build(encodingBy: codingFactory.createEncoder(), metadata: codingFactory.metadata)

            return DAppExtrinsicRawSignatureResult(sender: builderResult.sender, signedExtrinsic: signedExtrinsic)
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
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        let signatureWrapper = createRawSignatureOperation(
            for: processedResult,
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
        for signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<DAppExtrinsicRawSignatureResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderWrapper = createBaseBuilderWrapper(
            for: processedResult,
            codingFactoryOperation: codingFactoryOperation
        )

        builderWrapper.addDependency(operations: [codingFactoryOperation])

        let signOperation = ClosureOperation<DAppExtrinsicRawSignatureResult> {
            let builderResult = try builderWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let builder = builderResult.builder
            let context = ExtrinsicSigningContext.substrateExtrinsic(
                .init(
                    senderResolution: builderResult.sender,
                    extrinsicMemo: builder.makeMemo(),
                    codingFactory: codingFactory
                )
            )

            let rawSignature = try builder.buildRawSignature(
                using: { data in
                    try signingClosure(data, context)
                },
                encoder: codingFactory.createEncoder(),
                metadata: codingFactory.metadata
            )

            return DAppExtrinsicRawSignatureResult(sender: builderResult.sender, signedExtrinsic: rawSignature)
        }

        signOperation.addDependency(builderWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + builderWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: signOperation, dependencies: dependencies)
    }
}
