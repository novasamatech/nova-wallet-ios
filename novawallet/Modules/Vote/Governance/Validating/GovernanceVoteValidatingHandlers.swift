struct GovernanceVoteValidatingHandlers {
    let convictionUpdateClosure: (() -> Void)?
    let feeErrorClosure: () -> Void

    init(
        convictionUpdateClosure: (() -> Void)? = nil,
        feeErrorClosure: @escaping () -> Void
    ) {
        self.convictionUpdateClosure = convictionUpdateClosure
        self.feeErrorClosure = feeErrorClosure
    }
}
