import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

class BaseExtrinsicOperationFactory {
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let feeEstimationRegistry: ExtrinsicFeeEstimationRegistring
    let operationManager: OperationManagerProtocol
    let usesStateCallForFee: Bool

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        feeEstimationRegistry: ExtrinsicFeeEstimationRegistring,
        operationManager: OperationManagerProtocol,
        usesStateCallForFee: Bool
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.feeEstimationRegistry = feeEstimationRegistry
        self.operationManager = operationManager
        self.usesStateCallForFee = usesStateCallForFee
    }

    func createDummySigner(for _: MultiassetCryptoType) throws -> DummySigner {
        fatalError("Subclass must override this method")
    }

    func createExtrinsicWrapper(
        customClosure _: @escaping ExtrinsicBuilderIndexedClosure,
        indexes _: [Int],
        payingFeeIn _: ChainAssetId?,
        signingClosure _: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        fatalError("Subclass must override this method")
    }
}

extension BaseExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { engine }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: IndexSet,
        payingIn chainAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        let signingClosure: (Data, ExtrinsicSigningContext) throws -> Data = { data, context in
            guard let cryptoType = context.substrateCryptoType else {
                throw CommonError.undefined
            }

            let signer = try self.createDummySigner(for: cryptoType)

            return try signer.sign(data, context: context).rawData()
        }

        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicWrapper(
            customClosure: closure,
            indexes: indexList,
            payingFeeIn: chainAssetId,
            signingClosure: signingClosure
        )

        let coderFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let feeWrapper = feeEstimationRegistry.createFeeEstimatingWrapper(
            payingIn: chainAssetId,
            extrinsicCreatingResultClosure: {
                try builderWrapper.targetOperation.extractNoCancellableResultData()
            }
        )

        feeWrapper.addDependency(operations: [coderFactoryOperation])
        feeWrapper.addDependency(wrapper: builderWrapper)

        let wrapperOperation = ClosureOperation<ExtrinsicRetriableResult<ExtrinsicFeeProtocol>> {
            do {
                let result = try feeWrapper.targetOperation.extractNoCancellableResultData()

                let indexedResults = zip(indexList, result.items).map { indexedResult in
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

        wrapperOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: builderWrapper.allOperations + [coderFactoryOperation])
            .insertingTail(operation: wrapperOperation)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        indexes: IndexSet,
        payingIn chainAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let signingClosure: (Data, ExtrinsicSigningContext) throws -> Data = { data, context in
            try signer.sign(data, context: context).rawData()
        }

        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicWrapper(
            customClosure: closure,
            indexes: indexList,
            payingFeeIn: chainAssetId,
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
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData().extrinsics
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
            // TODO: Move to a better place
            let sender = try builderWrapper.targetOperation.extractNoCancellableResultData().sender

            let indexedResults = zip(indexList, submitOperationList).map { indexedOperation in

                if let result = indexedOperation.1.result {
                    let mappedResult = result.map { txHash in
                        ExtrinsicSubmitedModel(txHash: txHash, sender: sender)
                    }
                    return SubmitIndexedExtrinsicResult.IndexedResult(index: indexedOperation.0, result: mappedResult)
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
        signer: SigningWrapperProtocol,
        payingFeeIn chainAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<String> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let signingClosure: (Data, ExtrinsicSigningContext) throws -> Data = { data, context in
            try signer.sign(data, context: context).rawData()
        }

        let builderWrapper = createExtrinsicWrapper(
            customClosure: wrapperClosure,
            indexes: [0],
            payingFeeIn: chainAssetId,
            signingClosure: signingClosure
        )

        let resOperation: ClosureOperation<String> = ClosureOperation {
            let extrinsic = try builderWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics
                .first!

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
