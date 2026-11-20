import Foundation
import Operation_iOS

struct AssetExchangeOperationFailure: Error {
    enum Stage: Equatable {
        case notSubmitted
        case submitted(txHash: ExtrinsicHash)
    }

    let stage: Stage
    let error: Error
}

extension AssetExchangeOperationFailure {
    init(wrapping error: Error) {
        if let failure = error as? AssetExchangeOperationFailure {
            self = failure
        } else {
            self.init(stage: .notSubmitted, error: error)
        }
    }

    var submittedTxHash: ExtrinsicHash? {
        switch stage {
        case .notSubmitted:
            nil
        case let .submitted(txHash):
            txHash
        }
    }
}

extension CompoundOperationWrapper {
    func failingWithSubmissionStage(
        _ submittedTxHashClosure: @escaping () -> ExtrinsicHash?
    ) -> CompoundOperationWrapper<ResultType> {
        let resultOperation = targetOperation

        let stagingOperation = ClosureOperation<ResultType> {
            do {
                return try resultOperation.extractNoCancellableResultData()
            } catch {
                guard let txHash = submittedTxHashClosure() else {
                    throw error
                }

                throw AssetExchangeOperationFailure(stage: .submitted(txHash: txHash), error: error)
            }
        }

        stagingOperation.addDependency(resultOperation)

        return insertingTail(operation: stagingOperation)
    }
}

extension BaseOperation where ResultType == ExtrinsicSubmittedModel {
    var submittedTxHash: ExtrinsicHash? {
        guard case let .success(submittedModel) = result else {
            return nil
        }

        return submittedModel.txHash
    }
}

extension BaseOperation where ResultType == XcmSubmitExtrinsic {
    var submittedTxHash: ExtrinsicHash? {
        guard case let .success(submission) = result else {
            return nil
        }

        return submission.submittedModel.txHash
    }
}
