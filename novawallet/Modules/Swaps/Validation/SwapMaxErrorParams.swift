struct SwapMaxErrorParams {
    let maxSwap: String
    let fee: String
    let existentialDeposit: ExistensialDepositErrorParams?

    struct ExistensialDepositErrorParams {
        let fee: String
        let value: String
        let token: String
    }
}
