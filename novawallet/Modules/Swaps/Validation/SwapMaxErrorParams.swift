struct SwapMaxErrorParams {
    struct ExistensialDeposit {
        let fee: String
        let value: String
        let token: String
    }

    let maxSwap: String
    let fee: String
    let existentialDeposit: ExistensialDeposit?
}
