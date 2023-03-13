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
            guard let result = try feeOperation.targetOperation.extractNoCancellableResultData().results.first?.result else {
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
            guard let result = try submitOperation.targetOperation.extractNoCancellableResultData().results.first?.result else {
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

final class ExtrinsicOperationFactory {
    let accountId: AccountId
    let cryptoType: MultiassetCryptoType
    let signaturePayloadFormat: ExtrinsicSignaturePayloadFormat
    let chain: ChainModel
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let customExtensions: [ExtrinsicExtension]
    let engine: JSONRPCEngine
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

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
        self.runtimeRegistry = runtimeRegistry
        self.customExtensions = customExtensions
        self.engine = engine
        self.eraOperationFactory = eraOperationFactory
        self.operationManager = operationManager
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

    private func createExtrinsicOperation(
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

    private func createTipInclusionOperation(
        dependingOn infoOperation: BaseOperation<RuntimeDispatchInfo>,
        extrinsicData: Data,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> BaseOperation<RuntimeDispatchInfo> {
        ClosureOperation<RuntimeDispatchInfo> {
            let info = try infoOperation.extractNoCancellableResultData()

            guard let baseFee = BigUInt(info.fee) else {
                return info
            }

            let decoder = try codingFactory.createDecoder(from: extrinsicData)
            let context = codingFactory.createRuntimeJsonContext()
            let decodedExtrinsic: Extrinsic = try decoder.read(
                of: GenericType.extrinsic.name,
                with: context.toRawContext()
            )

            if let tip = decodedExtrinsic.signature?.extra.getTip() {
                let newFee = baseFee + tip
                return RuntimeDispatchInfo(
                    fee: String(newFee),
                    weight: info.weight
                )
            } else {
                return info
            }
        }
    }

    private func createStateCallFeeWrapper(
        for factory: RuntimeCoderFactoryProtocol,
        type: String,
        extrinsic: Data,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        let requestOperation = ClosureOperation<StateCallRpc.Request> {
            let lengthEncoder = factory.createEncoder()
            try lengthEncoder.appendU32(json: .stringValue(String(extrinsic.count)))
            let lengthInBytes = try lengthEncoder.encode()

            let totalBytes = extrinsic + lengthInBytes

            return StateCallRpc.Request(builtInFunction: StateCallRpc.feeBuiltIn) { container in
                try container.encode(totalBytes.toHex(includePrefix: true))
            }
        }

        let infoOperation = JSONRPCOperation<StateCallRpc.Request, String>(
            engine: connection,
            method: StateCallRpc.method
        )

        infoOperation.configurationBlock = {
            do {
                infoOperation.parameters = try requestOperation.extractNoCancellableResultData()
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(requestOperation)

        let mapOperation = ClosureOperation<RuntimeDispatchInfo> {
            let result = try infoOperation.extractNoCancellableResultData()
            let resultData = try Data(hexString: result)
            let decoder = try factory.createDecoder(from: resultData)
            let remoteModel = try decoder.read(type: type).map(
                to: RemoteRuntimeDispatchInfo.self,
                with: factory.createRuntimeJsonContext().toRawContext()
            )

            return .init(fee: String(remoteModel.fee), weight: remoteModel.weight)
        }

        mapOperation.addDependency(infoOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [requestOperation, infoOperation]
        )
    }

    private func createApiFeeWrapper(
        extrinsic: Data,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
            engine: connection,
            method: RPCMethod.paymentInfo,
            parameters: [extrinsic.toHex(includePrefix: true)]
        )

        return CompoundOperationWrapper(targetOperation: infoOperation)
    }

    private func createFeeOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        extrinsicOperation: BaseOperation<[Data]>,
        connection: JSONRPCEngine
    ) -> BaseOperation<[RuntimeDispatchInfo]> {
        OperationCombiningService<RuntimeDispatchInfo>(
            operationManager: operationManager
        ) {
            let coderFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let extrinsics = try extrinsicOperation.extractNoCancellableResultData()

            let feeType = StateCallRpc.feeResultType
            let hasFeeType = coderFactory.hasType(for: feeType)

            let feeOperationWrappers: [CompoundOperationWrapper<RuntimeDispatchInfo>] =
                extrinsics.map { extrinsicData in
                    let feeWrapper: CompoundOperationWrapper<RuntimeDispatchInfo>

                    if hasFeeType {
                        feeWrapper = self.createStateCallFeeWrapper(
                            for: coderFactory,
                            type: feeType,
                            extrinsic: extrinsicData,
                            connection: connection
                        )
                    } else {
                        feeWrapper = self.createApiFeeWrapper(
                            extrinsic: extrinsicData,
                            connection: connection
                        )
                    }

                    let tipInclusionOperation = self.createTipInclusionOperation(
                        dependingOn: feeWrapper.targetOperation,
                        extrinsicData: extrinsicData,
                        codingFactory: coderFactory
                    )

                    tipInclusionOperation.addDependency(feeWrapper.targetOperation)

                    return CompoundOperationWrapper(
                        targetOperation: tipInclusionOperation,
                        dependencies: feeWrapper.allOperations
                    )
                }

            return feeOperationWrappers
        }.longrunOperation()
    }
}

extension ExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { engine }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            indexes: indexList,
            signingClosure: signingClosure
        )

        let coderFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let feeOperation = createFeeOperation(
            dependingOn: coderFactoryOperation,
            extrinsicOperation: builderWrapper.targetOperation,
            connection: connection
        )

        feeOperation.addDependency(coderFactoryOperation)
        feeOperation.addDependency(builderWrapper.targetOperation)

        let wrapperOperation = ClosureOperation<ExtrinsicRetriableResult<RuntimeDispatchInfo>> {
            do {
                let results = try feeOperation.extractNoCancellableResultData()

                let indexedResults = zip(indexList, results).map { indexedResult in
                    FeeIndexedExtrinsicResult.IndexedResult(
                        index: indexedResult.0,
                        result: .success(indexedResult.1)
                    )
                }

                return .init(builderClosure: closure, results: indexedResults)
            } catch {
                let indexedResults = indexList.map { index in
                    FeeIndexedExtrinsicResult.IndexedResult(index: index, result: .failure(error))
                }

                return .init(builderClosure: closure, results: indexedResults)
            }
        }

        wrapperOperation.addDependency(feeOperation)

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + [coderFactoryOperation, feeOperation]
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            indexes: indexList,
            signingClosure: signingClosure
        )

        let submitOperationList: [JSONRPCListOperation<String>] =
            indexList.map { index in
                let submitOperation = JSONRPCListOperation<String>(
                    engine: engine,
                    method: RPCMethod.submitExtrinsic
                )

                submitOperation.configurationBlock = {
                    do {
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData()
                        let extrinsic = extrinsics[index].toHex(includePrefix: true)

                        submitOperation.parameters = [extrinsic]
                    } catch {
                        submitOperation.result = .failure(error)
                    }
                }

                submitOperation.addDependency(builderWrapper.targetOperation)

                return submitOperation
            }

        let wrapperOperation = ClosureOperation<SubmitIndexedExtrinsicResult> {
            let indexedResults = zip(indexList, submitOperationList).map { indexedOperation in
                if let result = indexedOperation.1.result {
                    return SubmitIndexedExtrinsicResult.IndexedResult(index: indexedOperation.0, result: result)
                } else {
                    return SubmitIndexedExtrinsicResult.IndexedResult(
                        index: indexedOperation.0,
                        result: .failure(BaseOperationError.parentOperationCancelled)
                    )
                }
            }

            return .init(builderClosure: closure, results: indexedResults)
        }

        submitOperationList.forEach { submitOperation in
            wrapperOperation.addDependency(submitOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + submitOperationList
        )
    }

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: wrapperClosure,
            indexes: [0],
            signingClosure: signingClosure
        )

        let resOperation: ClosureOperation<String> = ClosureOperation {
            let extrinsic = try builderWrapper.targetOperation.extractNoCancellableResultData().first!
            return extrinsic.toHex(includePrefix: true)
        }
        builderWrapper.allOperations.forEach {
            resOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: resOperation,
            dependencies: builderWrapper.allOperations
        )
    }
}
