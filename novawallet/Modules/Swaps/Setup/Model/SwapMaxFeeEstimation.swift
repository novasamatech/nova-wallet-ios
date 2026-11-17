import Foundation

struct SwapMaxFeeEstimation {
    static let debounceDelay: TimeInterval = 0.5

    struct Pair: Equatable {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
        let feeAssetId: ChainAssetId
    }

    private struct Estimate {
        let pair: Pair
        let fee: AssetExchangeFee
    }

    private(set) var isSpent = false
    private var startedPair: Pair?
    private var pendingQuoteArgs: AssetConversion.QuoteArgs?
    private var estimate: Estimate?

    mutating func start(for pair: Pair, quoteArgs: AssetConversion.QuoteArgs) -> Bool {
        guard !isSpent else {
            return false
        }

        isSpent = true
        startedPair = pair
        pendingQuoteArgs = quoteArgs
        estimate = nil

        return true
    }

    mutating func complete(with fee: AssetExchangeFee, for quoteArgs: AssetConversion.QuoteArgs) -> Bool {
        guard
            let startedPair,
            pendingQuoteArgs == quoteArgs,
            fee.feeAssetId == startedPair.feeAssetId else {
            return false
        }

        pendingQuoteArgs = nil
        estimate = Estimate(pair: startedPair, fee: fee)

        return true
    }

    mutating func cancel() {
        isSpent = true
        pendingQuoteArgs = nil
        estimate = nil
    }

    mutating func reset() {
        cancel()
        isSpent = false
        startedPair = nil
    }

    func fee(for pair: Pair) -> AssetExchangeFee? {
        estimate?.pair == pair ? estimate?.fee : nil
    }
}
