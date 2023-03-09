enum StakingRebagConfirmError: Error {
    case fetchPriceFailed(Error)
    case fetchBalanceFailed(Error)
    case fetchFeeFailed(Error)
    case fetchStashItemFailed(Error)
    case fetchBagListScoreFactorFailed(Error)
    case fetchBagListNodeFailed(Error)
    case fetchLedgerInfoFailed(Error)
    case networkInfo(Error)
    case submitFailed(Error)
}
