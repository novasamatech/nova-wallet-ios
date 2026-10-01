import Foundation

struct SubtensorConfirmQuoteState {
    private(set) var acknowledged: SubtensorTradeQuote?
    private(set) var isPriceMoved = false
    private(set) var isLatestFailed = false
    private var flow = SubtensorQuoteFlowModel()

    init(request: SubtensorTradeQuoteRequest, acknowledged: SubtensorTradeQuote?) {
        _ = flow.updateRequest(request)

        if let acknowledged, flow.applyQuote(acknowledged) {
            self.acknowledged = acknowledged
        }
    }

    var request: SubtensorTradeQuoteRequest? {
        flow.request
    }

    var latest: SubtensorTradeQuote? {
        flow.freshQuote
    }

    var latestCrossesAcknowledgedLimit: Bool {
        guard let latest, let acknowledged else {
            return false
        }

        return !latest.isFillable(atLimit: acknowledged.limitPrice)
    }

    mutating func apply(latest quote: SubtensorTradeQuote) -> Bool {
        guard flow.applyQuote(quote) else {
            return false
        }

        isLatestFailed = false

        if acknowledged == nil {
            acknowledged = quote
        } else if latestCrossesAcknowledgedLimit {
            isPriceMoved = true
        }

        return true
    }

    mutating func acknowledgeLatest() -> Bool {
        guard let latest else {
            return false
        }

        acknowledged = latest
        isPriceMoved = false

        return true
    }

    mutating func raisePriceMovedIfCrossed() -> Bool {
        guard latestCrossesAcknowledgedLimit else {
            return false
        }

        isPriceMoved = true

        return true
    }

    mutating func raisePriceMoved() {
        isPriceMoved = true
    }

    mutating func invalidateLatest() {
        flow.clearQuote()
    }

    mutating func markLatestFailed() {
        flow.clearQuote()
        isLatestFailed = true
    }
}
