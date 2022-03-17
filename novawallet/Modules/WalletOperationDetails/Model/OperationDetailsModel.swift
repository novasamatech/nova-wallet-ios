import Foundation

struct OperationDetailsModel {
    enum Status {
        case completed
        case pending
        case failed
    }

    enum OperationData {
        case transfer(_ model: OperationTransferModel)
        case reward(_ model: OperationRewardModel)
        case slash(_ model: OperationSlashModel)
        case extrinsic(_ model: OperationExtrinsicModel)
    }

    let time: Date
    let status: Status
    let operation: OperationData
}
