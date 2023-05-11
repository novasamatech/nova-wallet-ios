import Foundation
import SubstrateSdk
import RobinHood

final class DAppExtrinsicBuilderOperationFactory {
    let processedResult: DAppOperationProcessedResult
    let runtimeProvider: RuntimeCodingServiceProtocol

    init(processedResult: DAppOperationProcessedResult, runtimeProvider: RuntimeCodingServiceProtocol) {
        self.processedResult = processedResult
        self.runtimeProvider = runtimeProvider
    }

    private func createBaseBuilderOperation(
        for result: DAppOperationProcessedResult,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ExtrinsicBuilderProtocol> {
        ClosureOperation<ExtrinsicBuilderProtocol> {
            let runtimeContext = try codingFactoryOperation.extractNoCancellableResultData().createRuntimeJsonContext()

            let extrinsic = result.extrinsic

            let address = MultiAddress.accoundId(result.account.accountId)

            var builder: ExtrinsicBuilderProtocol = try ExtrinsicBuilder(
                specVersion: extrinsic.specVersion,
                transactionVersion: extrinsic.transactionVersion,
                genesisHash: extrinsic.genesisHash
            )
            .with(signaturePayloadFormat: result.account.type.signaturePayloadFormat)
            .with(runtimeJsonContext: runtimeContext)
            .with(address: address)
            .with(nonce: UInt32(extrinsic.nonce))
            .with(era: extrinsic.era, blockHash: extrinsic.blockHash)
            .adding(extrinsicExtension: ChargeAssetTxPayment())

            builder = try result.extrinsic.method.accept(builder: builder)

            if extrinsic.tip > 0 {
                builder = builder.with(tip: extrinsic.tip)
            }

            return builder
        }
    }

    private func createRawSignatureOperation(
        for result: DAppOperationProcessedResult,
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderOperation = createBaseBuilderOperation(
            for: result,
            codingFactoryOperation: codingFactoryOperation
        )

        builderOperation.addDependency(codingFactoryOperation)

        let payloadOperation = ClosureOperation<Data> {
            let builder = try builderOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try builder.signing(
                with: { try signingClosure($0) },
                chainFormat: result.account.chainFormat,
                cryptoType: result.account.cryptoType,
                codingFactory: codingFactory
            )
            .build(encodingBy: codingFactory.createEncoder(), metadata: codingFactory.metadata)
        }

        payloadOperation.addDependency(codingFactoryOperation)
        payloadOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: payloadOperation,
            dependencies: [codingFactoryOperation, builderOperation]
        )
    }
}

extension DAppExtrinsicBuilderOperationFactory: ExtrinsicBuilderOperationFactoryProtocol {
    func createWrapper(
        customClosure _: @escaping ExtrinsicBuilderIndexedClosure,
        indexes _: [Int],
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderOperation = createBaseBuilderOperation(
            for: processedResult,
            codingFactoryOperation: codingFactoryOperation
        )

        builderOperation.addDependency(codingFactoryOperation)

        let signatureWrapper = createRawSignatureOperation(
            for: processedResult,
            signingClosure: signingClosure
        )

        signatureWrapper.addDependency(operations: [builderOperation])

        let mappingOperation = ClosureOperation<[Data]> {
            let data = try signatureWrapper.targetOperation.extractNoCancellableResultData()

            return [data]
        }

        mappingOperation.addDependency(signatureWrapper.targetOperation)

        let dependencies = [codingFactoryOperation, builderOperation] + signatureWrapper.allOperations

        let wrapper = CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)

        return wrapper
    }

    func createDummySigner() throws -> DummySigner {
        try DummySigner(cryptoType: processedResult.account.cryptoType)
    }
}
