enum SwipeGovSetupInteractorError {
    case assetBalanceFailed(_ internalError: Error)
    case priceFailed(_ internalError: Error)
    case blockNumberSubscriptionFailed(_ internalError: Error)
    case blockTimeFailed(_ internalError: Error)
    case stateDiffFailed(_ internalError: Error)
    case votingPowerSaveFailed(_ internalError: Error)
}
