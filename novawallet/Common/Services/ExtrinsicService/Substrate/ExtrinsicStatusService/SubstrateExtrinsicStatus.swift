import Foundation

enum SubstrateExtrinsicStatus {
    struct SuccessExtrinsic {
        let extrinsicHash: ExtrinsicHash
        let blockHash: BlockHash
        let interestedEvents: [Event]
    }

    struct FailedExtrinsic {
        let extrinsicHash: ExtrinsicHash
        let blockHash: BlockHash
        let error: DispatchCallError
    }

    case success(SuccessExtrinsic)
    case failure(FailedExtrinsic)
}

extension Result where Success == SubstrateExtrinsicStatus {
    func getSuccessExtrinsicStatus() throws -> SubstrateExtrinsicStatus.SuccessExtrinsic {
        let executionStatus = try get()

        switch executionStatus {
        case let .success(successStatus):
            return successStatus
        case let .failure(failureStature):
            throw failureStature.error
        }
    }
}
