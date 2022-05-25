import Foundation
import RobinHood
import SubstrateSdk
import IrohaCrypto
import BigInt

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)

protocol ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    )
        -> CompoundOperationWrapper<[FeeExtrinsicResult]>

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]>

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String>
}

extension ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(_ closure: @escaping ExtrinsicBuilderClosure)
        -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let feeOperation = estimateFeeOperation(
            wrapperClosure,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<RuntimeDispatchInfo> {
            guard let result = try feeOperation.targetOperation.extractNoCancellableResultData().first else {
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
            guard let result = try submitOperation.targetOperation.extractNoCancellableResultData().first else {
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
    let chain: ChainModel
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let customExtensions: [ExtrinsicExtension]
    let engine: JSONRPCEngine
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol

    init(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        customExtensions: [ExtrinsicExtension],
        engine: JSONRPCEngine,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol = MortalEraOperationFactory()
    ) {
        self.accountId = accountId
        self.chain = chain
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.customExtensions = customExtensions
        self.engine = engine
        self.eraOperationFactory = eraOperationFactory
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
        numberOfExtrinsics: Int,
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        let currentCryptoType = cryptoType
        let currentAccountId = accountId
        let currentChainFormat = chain.chainFormat
        let currentExtensions = customExtensions
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

            let extrinsics: [Data] = try (0 ..< numberOfExtrinsics).map { index in
                var builder: ExtrinsicBuilderProtocol = ExtrinsicBuilder(
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    genesisHash: genesisHash
                )
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
        dependingOn infoOperation: JSONRPCListOperation<RuntimeDispatchInfo>,
        coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<RuntimeDispatchInfo> {
        ClosureOperation<RuntimeDispatchInfo> {
            let info = try infoOperation.extractNoCancellableResultData()

            guard let baseFee = BigUInt(info.fee) else {
                return info
            }

            guard let hexExtrinsic = infoOperation.parameters?.first else {
                return info
            }

            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let extrinsicData = try Data(hexString: hexExtrinsic)

            let decoder = try codingFactory.createDecoder(from: extrinsicData)
            let context = codingFactory.createRuntimeJsonContext()
            let decodedExtrinsic: Extrinsic = try decoder.read(
                of: GenericType.extrinsic.name,
                with: context.toRawContext()
            )

            if let tip = decodedExtrinsic.signature?.extra.getTip() {
                let newFee = baseFee + tip
                return RuntimeDispatchInfo(
                    dispatchClass: info.dispatchClass,
                    fee: String(newFee),
                    weight: info.weight
                )
            } else {
                return info
            }
        }
    }
}

extension ExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        let coderFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let feeOperationWrappers: [CompoundOperationWrapper<RuntimeDispatchInfo>] =
            (0 ..< numberOfExtrinsics).map { index in
                let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
                    engine: engine,
                    method: RPCMethod.paymentInfo
                )

                infoOperation.configurationBlock = {
                    do {
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData()
                        let extrinsic = extrinsics[index].toHex(includePrefix: true)
                        infoOperation.parameters = [extrinsic]
                    } catch {
                        infoOperation.result = .failure(error)
                    }
                }

                infoOperation.addDependency(builderWrapper.targetOperation)

                let tipInclusionOperation = createTipInclusionOperation(
                    dependingOn: infoOperation,
                    coderFactoryOperation: coderFactoryOperation
                )

                tipInclusionOperation.addDependency(infoOperation)

                return CompoundOperationWrapper(targetOperation: tipInclusionOperation, dependencies: [infoOperation])
            }

        let wrapperOperation = ClosureOperation<[FeeExtrinsicResult]> {
            feeOperationWrappers.map { feeWrapper in
                if let result = feeWrapper.targetOperation.result {
                    return result
                } else {
                    return .failure(BaseOperationError.parentOperationCancelled)
                }
            }
        }

        feeOperationWrappers.forEach { feeWrapper in
            feeWrapper.addDependency(operations: [coderFactoryOperation])
            wrapperOperation.addDependency(feeWrapper.targetOperation)
        }

        let rawFeeOperations = feeOperationWrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + [coderFactoryOperation] + rawFeeOperations
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        let submitOperationList: [JSONRPCListOperation<String>] =
            (0 ..< numberOfExtrinsics).map { index in
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

        let wrapperOperation = ClosureOperation<[SubmitExtrinsicResult]> {
            submitOperationList.map { submitOperation in
                if let result = submitOperation.result {
                    return result
                } else {
                    return .failure(BaseOperationError.parentOperationCancelled)
                }
            }
        }

        submitOperationList.forEach { submitOperation in
            wrapperOperation.addDependency(submitOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + submitOperationList
        )
    }

    func submitAndWatch(
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
            numberOfExtrinsics: 1,
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
