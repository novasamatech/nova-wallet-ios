import Foundation

struct OperationDetailsModel {
    enum Status {
        case completed
        case pending
        case failed
    }

    enum OperationData {
        case transfer(_ model: OperationTransferModel)
        case reward(_ model: OperationRewardOrSlashModel)
        case slash(_ model: OperationRewardOrSlashModel)
        case extrinsic(_ model: OperationExtrinsicModel)
        case contract(_ model: OperationContractCallModel)
        case poolReward(_ model: OperationPoolRewardOrSlashModel)
        case poolSlash(_ model: OperationPoolRewardOrSlashModel)
        case swap(_ model: OperationSwapModel)
    }

    let time: Date
    let status: Status
    let operation: OperationData
}
