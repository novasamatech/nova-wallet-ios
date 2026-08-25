import Foundation

enum SubtensorExecutedOutcome: Equatable {
    case staked(tao: Balance)
    case unstaked(tao: Balance)
    case claimed(tao: Balance)
}

struct SubtensorSubmissionModel {
    let submitted: ExtrinsicSubmittedModel
    let outcome: SubtensorExecutedOutcome?
}
