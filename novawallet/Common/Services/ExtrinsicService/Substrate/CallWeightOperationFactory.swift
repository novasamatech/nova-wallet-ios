import Foundation
import Operation_iOS

protocol CallWeightEstimatingFactoryProtocol {
    func estimateWeight(
        for calls: [RuntimeCallCollecting],
        operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<[CallCodingPath: Substrate.Weight]>
}

final class CallWeightEstimatingFactory {}

extension CallWeightEstimatingFactory: CallWeightEstimatingFactoryProtocol {
    func estimateWeight(
        for calls: [RuntimeCallCollecting],
        operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<[CallCodingPath: Substrate.Weight]> {
        let callTypes = calls.reduce(into: [CallCodingPath: RuntimeCallCollecting]()) { accum, call in
            if accum[call.callPath] == nil {
                accum[call.callPath] = call
            }
        }

        let targetCalls = Array(callTypes.values)

        guard !targetCalls.isEmpty else {
            return CompoundOperationWrapper.createWithResult([:])
        }

        let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
            try targetCalls[index].addingToExtrinsic(builder: builder)
        }

        let feeWrapper = operationFactory.estimateFeeOperation(closure, numberOfExtrinsics: callTypes.count)

        let mergeOperation = ClosureOperation<[CallCodingPath: Substrate.Weight]> {
            let feeResults = try feeWrapper.targetOperation.extractNoCancellableResultData().results

            return try zip(targetCalls, feeResults).reduce(into: [CallCodingPath: Substrate.Weight]()) { accum, pair in
                let callPath = pair.0.callPath
                let feeResult = pair.1.result

                let fee = try feeResult.get()
                accum[callPath] = fee.weight
            }
        }

        mergeOperation.addDependency(feeWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: feeWrapper.allOperations)
    }
}
