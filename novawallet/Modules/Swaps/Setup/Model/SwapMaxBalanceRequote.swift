import Foundation

struct SwapMaxBalanceRequote {
    static let throttleWindow: TimeInterval = 10
    static let payBalanceTimeout: TimeInterval = 5

    var lastRequoteDate: Date?
    var quietQuoteArgs: AssetConversion.QuoteArgs?
    var isCatchUpPending = false
    var awaitedPayAssetId: ChainAssetId?

    var isAwaitingPayBalance: Bool {
        awaitedPayAssetId != nil
    }

    func delayUntilNextRequote(at date: Date = Date()) -> TimeInterval {
        guard let lastRequoteDate else {
            return 0
        }

        return max(Self.throttleWindow - date.timeIntervalSince(lastRequoteDate), 0)
    }
}
