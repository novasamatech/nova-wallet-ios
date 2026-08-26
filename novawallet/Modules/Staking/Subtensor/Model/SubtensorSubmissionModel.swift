import Foundation

enum SubtensorExecutedOutcome: Equatable {
    case staked(tao: Balance, alpha: Balance, netuid: UInt16)
    case unstaked(tao: Balance, alpha: Balance, netuid: UInt16)
    case claimed(tao: Balance)
}

struct SubtensorSubmissionModel {
    let submitted: ExtrinsicSubmittedModel
    let outcome: SubtensorExecutedOutcome?
}
