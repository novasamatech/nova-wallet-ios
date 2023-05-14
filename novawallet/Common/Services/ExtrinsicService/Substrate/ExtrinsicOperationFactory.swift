import Foundation
import RobinHood
import SubstrateSdk
import IrohaCrypto
import BigInt

protocol ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { get }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult>

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult>

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String>
}

extension ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        estimateFeeOperation(closure, indexes: IndexSet(0 ..< numberOfExtrinsics))
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        submit(closure, signer: signer, indexes: IndexSet(0 ..< numberOfExtrinsics))
    }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let feeOperation = estimateFeeOperation(
            wrapperClosure,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<RuntimeDispatchInfo> {
            guard let result = try feeOperation.targetOperation.extractNoCancellableResultData()
                .results.first?.result else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: feeOperation.allOperations
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let submitOperation = submit(
            wrapperClosure,
            signer: signer,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<String> {
            guard let result = try submitOperation.targetOperation.extractNoCancellableResultData()
                .results.first?.result else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(submitOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: submitOperation.allOperations
        )
    }
}

final class ExtrinsicOperationFactory: BaseExtrinsicOperationFactory {
    let accountId: AccountId
    let cryptoType: MultiassetCryptoType
    let signaturePayloadFormat: ExtrinsicSignaturePayloadFormat
    let chain: ChainModel
    let customExtensions: [ExtrinsicExtension]
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol

    init(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType,
        signaturePayloadFormat: ExtrinsicSignaturePayloadFormat,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        customExtensions: [ExtrinsicExtension],
        engine: JSONRPCEngine,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol = MortalEraOperationFactory(),
        operationManager: OperationManagerProtocol
    ) {
        self.accountId = accountId
        self.chain = chain
        self.cryptoType = cryptoType
        self.signaturePayloadFormat = signaturePayloadFormat
        self.customExtensions = customExtensions
        self.eraOperationFactory = eraOperationFactory

        super.init(
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        do {
            let address = try accountId.toAddress(using: chain.chainFormat)
            return JSONRPCListOperation<UInt32>(
                engine: engine,
                method: RPCMethod.getExtrinsicNonce,
                parameters: [address]
            )
        } catch {
            return BaseOperation.createWithError(error)
        }
    }

    private func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash
        )

        requestOperation.configurationBlock = {
            do {
                let blockNumber = try numberClosure()
                requestOperation.parameters = [blockNumber.toHex()]
            } catch {
                requestOperation.result = .failure(error)
            }
        }

        return requestOperation
    }

    override func createExtrinsicWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        let currentCryptoType = cryptoType
        let currentAccountId = accountId
        let currentChainFormat = chain.chainFormat
        let currentExtensions = customExtensions
        let currentSignaturePayloadFormat = signaturePayloadFormat
        let optTip = chain.defaultTip

        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let genesisBlockOperation = createBlockHashOperation(connection: engine, for: { 0 })

        let eraWrapper = eraOperationFactory.createOperation(from: engine, runtimeService: runtimeRegistry)

        let eraBlockOperation = createBlockHashOperation(connection: engine) {
            try eraWrapper.targetOperation.extractNoCancellableResultData().blockNumber
        }

        eraBlockOperation.addDependency(eraWrapper.targetOperation)

        let extrinsicsOperation = ClosureOperation<[Data]> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let genesisHash = try genesisBlockOperation.extractNoCancellableResultData()
            let era = try eraWrapper.targetOperation.extractNoCancellableResultData().extrinsicEra
            let eraBlockHash = try eraBlockOperation.extractNoCancellableResultData()

            let runtimeJsonContext = codingFactory.createRuntimeJsonContext()

            let extrinsics: [Data] = try indexes.map { index in
                var builder: ExtrinsicBuilderProtocol = ExtrinsicBuilder(
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    genesisHash: genesisHash
                )
                .with(signaturePayloadFormat: currentSignaturePayloadFormat)
                .with(runtimeJsonContext: runtimeJsonContext)
                .with(era: era, blockHash: eraBlockHash)
                .with(nonce: nonce + UInt32(index))

                if let defaultTip = optTip {
                    builder = builder.with(tip: defaultTip)
                }

                for customExtension in currentExtensions {
                    builder = builder.adding(extrinsicExtension: customExtension)
                }

                let account = MultiAddress.accoundId(currentAccountId)
                builder = try builder.with(address: account)
                builder = try customClosure(builder, index).signing(
                    with: signingClosure,
                    chainFormat: currentChainFormat,
                    cryptoType: currentCryptoType,
                    codingFactory: codingFactory
                )

                return try builder.build(
                    encodingBy: codingFactory.createEncoder(),
                    metadata: codingFactory.metadata
                )
            }

            return extrinsics
        }

        let dependencies = [nonceOperation, codingFactoryOperation, genesisBlockOperation] +
            eraWrapper.allOperations + [eraBlockOperation]

        dependencies.forEach { extrinsicsOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: extrinsicsOperation, dependencies: dependencies)
    }

    override func createDummySigner() throws -> DummySigner {
        try DummySigner(cryptoType: cryptoType)
    }
}
