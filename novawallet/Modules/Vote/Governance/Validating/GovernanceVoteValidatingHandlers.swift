struct GovernanceVoteValidatingHandlers {
    let convictionUpdateClosure: () -> Void
    let feeErrorClosure: () -> Void
    let successClosure: DataValidationRunnerCompletion
}
