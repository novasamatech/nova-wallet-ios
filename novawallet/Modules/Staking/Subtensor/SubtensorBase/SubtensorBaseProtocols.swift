import Foundation

enum SubtensorFlowConstants {
    static let priceImpactWarningThreshold = BigRational(numerator: 1, denominator: 100)

    static func isHighPriceImpact(_ impact: BigRational) -> Bool {
        let threshold = priceImpactWarningThreshold

        return impact.numerator * threshold.denominator > threshold.numerator * impact.denominator
    }

    static let fullExitDriftThreshold = BigRational.percent(of: 1)

    static func exceedsFullExitDrift(live: Balance, reviewed: Balance) -> Bool {
        let drift = live > reviewed ? live - reviewed : reviewed - live
        let threshold = fullExitDriftThreshold

        return drift * threshold.denominator > reviewed * threshold.numerator
    }

    static let shieldQuoteAttempts = 3

    static let shieldQuoteTimeoutBlocks: BlockNumber = 2
}

protocol SubtensorBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for operation: SubtensorOperation)
    func estimateShieldQuote(for operation: SubtensorOperation)
    func cancelShieldQuote()
    func refreshPreflight(for hotkey: AccountId, netuid: UInt16)
    func refreshQuote(for request: SubtensorTradeQuoteRequest)
    func requestValidatingQuote(
        for request: SubtensorTradeQuoteRequest,
        completion: @escaping (Result<SubtensorTradeQuote, Error>) -> Void
    )
    func refreshPositions()
    func loadExistentialDeposit()
    func loadCatalogue()
    func loadSubnetLogos()
    func loadNovaFeeRate()
    func loadCostBasis(for netuid: UInt16)
    func loadRootHolds(for hotkeys: [AccountId])
    func retryRootHolds()
}

protocol SubtensorBaseInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveShieldQuote(_ quote: SubtensorShieldQuote?)
    func didReceivePositions(_ state: Multistaking.SubtensorState?)
    func didReceivePositionsSyncFailed(_ isFailed: Bool)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceivePreflight(_ preflight: SubtensorPreflight)
    func didReceiveQuote(_ quote: SubtensorTradeQuote)
    func didReceiveExistentialDeposit(_ deposit: Balance)
    func didReceiveBaseError(_ error: SubtensorBaseError)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
    func didReceiveNovaFeeRate(_ rate: BigRational?)
    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?)
    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold])
}

enum SubtensorBaseError: Error {
    case feeFailed(Error)
    case preflightFailed(Error)
    case quoteFailed(Error)
    case rootHoldsFailed(Error)
    case existentialDepositFailed(Error)
}

extension SubtensorBaseError {
    var isNovaFeeUnavailable: Bool {
        switch self {
        case let .feeFailed(error), let .quoteFailed(error):
            (error as? SubtensorOperationError) == .novaFeeUnavailable
        case .preflightFailed, .rootHoldsFailed, .existentialDepositFailed:
            false
        }
    }
}
