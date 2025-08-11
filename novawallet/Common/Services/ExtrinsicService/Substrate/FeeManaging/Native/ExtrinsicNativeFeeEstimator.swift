import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class ExtrinsicNativeFeeEstimator {
    let chain: ChainModel
    let operationQueue: OperationQueue

    init(chain: ChainModel, operationQueue: OperationQueue) {
        self.chain = chain
        self.operationQueue = operationQueue
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

            if let tip = decodedExtrinsic.getSignedExtrinsic()?.signature.extra.getTip() {
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

            return try decoder.read(type: type).map(
                to: RuntimeDispatchInfo.self,
                with: factory.createRuntimeJsonContext().toRawContext()
            )
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

    private func createFeeWrapper(
        coderFactory: RuntimeCoderFactoryProtocol,
        extrinsic: Data,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        if chain.feeViaRuntimeCall {
            let feeApi = coderFactory.metadata.getRuntimeApiMethod(
                for: StateCallRpc.feeBuiltInModule, methodName: StateCallRpc.feeBuiltInMethod
            )

            let feeTypeName = feeApi.map { String($0.method.output) } ?? StateCallRpc.feeResultType

            return createStateCallFeeWrapper(
                for: coderFactory,
                type: feeTypeName,
                extrinsic: extrinsic,
                connection: connection
            )
        } else {
            return createApiFeeWrapper(
                extrinsic: extrinsic,
                connection: connection
            )
        }
    }
}

extension ExtrinsicNativeFeeEstimator: ExtrinsicFeeEstimating {
    func createFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let feeOperation: BaseOperation<[RuntimeDispatchInfo]> = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let extrinsicsCreationResult = try extrinsicCreatingResultClosure()
            let extrinsics = extrinsicsCreationResult.extrinsics

            let feeOperationWrappers: [CompoundOperationWrapper<RuntimeDispatchInfo>] =
                extrinsics.map { extrinsicData in
                    let feeWrapper = self.createFeeWrapper(
                        coderFactory: coderFactory,
                        extrinsic: extrinsicData,
                        connection: connection
                    )

                    let tipInclusionOperation = self.createTipInclusionOperation(
                        dependingOn: feeWrapper.targetOperation,
                        extrinsicData: extrinsicData,
                        codingFactory: coderFactory
                    )

                    tipInclusionOperation.addDependency(feeWrapper.targetOperation)

                    return feeWrapper.insertingTail(operation: tipInclusionOperation)
                }

            return feeOperationWrappers
        }.longrunOperation()

        feeOperation.addDependency(coderFactoryOperation)

        let mapOperation = ClosureOperation<ExtrinsicFeeEstimationResultProtocol> {
            let dispatchInfoList = try feeOperation.extractNoCancellableResultData()
            let senderResolution = try extrinsicCreatingResultClosure().sender

            let payer = ExtrinsicFeePayer(senderResolution: senderResolution)

            let items = try dispatchInfoList.map { dispatchInfo in
                guard let fee = ExtrinsicFee(dispatchInfo: dispatchInfo, payer: payer) else {
                    throw ExtrinsicFeeEstimatingError.brokenFee
                }

                return fee
            }

            return ExtrinsicFeeEstimationResult(items: items)
        }

        mapOperation.addDependency(feeOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [coderFactoryOperation, feeOperation]
        )
    }
}
