import Foundation

struct SwapMaxFeeEstimation {
    static let debounceDelay: TimeInterval = 0.5

    struct Pair: Equatable {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
        let feeAssetId: ChainAssetId
    }

    private(set) var isSpent = false
    private var pending: (pair: Pair, quoteArgs: AssetConversion.QuoteArgs)?
    private var estimate: (pair: Pair, fee: AssetExchangeFee)?

    mutating func start(for pair: Pair, quoteArgs: AssetConversion.QuoteArgs) -> Bool {
        guard !isSpent else {
            return false
        }

        isSpent = true
        pending = (pair, quoteArgs)
        estimate = nil

        return true
    }

    mutating func complete(with fee: AssetExchangeFee, for quoteArgs: AssetConversion.QuoteArgs) -> Bool {
        guard let pending, pending.quoteArgs == quoteArgs else {
            return false
        }

        self.pending = nil
        estimate = (pending.pair, fee)

        return true
    }

    mutating func cancel() {
        isSpent = true
        pending = nil
        estimate = nil
    }

    mutating func reset() {
        self = .init()
    }

    func fee(for pair: Pair) -> AssetExchangeFee? {
        estimate?.pair == pair ? estimate?.fee : nil
    }
}
