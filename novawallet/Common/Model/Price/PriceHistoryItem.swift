import Foundation

struct PriceHistoryItem {
    let startedAt: TimeInterval
    let value: Decimal
}

struct PriceHistory {
    let currencyId: Int
    let items: [PriceHistoryItem]
}
