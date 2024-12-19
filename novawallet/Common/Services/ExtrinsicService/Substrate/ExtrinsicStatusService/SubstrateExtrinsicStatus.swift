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
        let error: DispatchExtrinsicError
    }

    case success(SuccessExtrinsic)
    case failure(FailedExtrinsic)
}
