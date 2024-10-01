import BigInt

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

struct GovBatchVoteValidatingHandlers {
    let convictionUpdateClosure: (() -> Void)?
    let maxAmountUpdateClosure: (BigUInt) -> Void
    let feeErrorClosure: () -> Void

    init(
        convictionUpdateClosure: (() -> Void)? = nil,
        maxAmountUpdateClosure: @escaping (BigUInt) -> Void,
        feeErrorClosure: @escaping () -> Void
    ) {
        self.convictionUpdateClosure = convictionUpdateClosure
        self.maxAmountUpdateClosure = maxAmountUpdateClosure
        self.feeErrorClosure = feeErrorClosure
    }
}
