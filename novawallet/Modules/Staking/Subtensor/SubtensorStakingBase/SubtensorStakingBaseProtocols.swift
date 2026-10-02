import Foundation

enum SubtensorStakingFlowConstants {
    static let blockTimeMillis: BlockTime = 12000

    static let priceImpactWarningThreshold = BigRational(numerator: 1, denominator: 100)

    static let quoteStalenessWindow: TimeInterval = 15

    static func isHighPriceImpact(_ impact: BigRational) -> Bool {
        let threshold = priceImpactWarningThreshold

        return impact.numerator * threshold.denominator > threshold.numerator * impact.denominator
    }
}

protocol SubtensorStakingBaseInteractorInputProtocol: AnyObject {
    func setup()
    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue>
    func cachedCostBasis(netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis>
    func estimateFee(for operation: SubtensorStakingOperation)
    func refreshPreflight(for hotkey: AccountId, netuid: UInt16)
    func refreshQuote(for request: SubtensorTradeQuoteRequest)
    func refreshPositions()
}

protocol SubtensorStakingBaseInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?)
    func didReceivePositionsSyncFailed(_ isFailed: Bool)
    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceivePreflight(_ preflight: SubtensorStakingPreflight)
    func didReceiveQuote(_ quote: SubtensorTradeQuote)
    func didReceiveExistentialDeposit(_ deposit: Balance)
    func didReceiveBaseError(_ error: SubtensorStakingBaseError)
}

enum SubtensorStakingBaseError: Error {
    case feeFailed(Error)
    case preflightFailed(Error)
    case quoteFailed(Error)
}

extension SubtensorStakingBaseError {
    var isNovaFeeUnavailable: Bool {
        switch self {
        case let .feeFailed(error), let .quoteFailed(error):
            (error as? SubtensorStakingOperationError) == .novaFeeUnavailable
        case .preflightFailed:
            false
        }
    }
}
