import Foundation

struct PriceHistoryItem: Codable, Equatable {
    let startedAt: UInt64
    let value: Decimal
}

struct PriceHistory: Codable, Equatable {
    let currencyId: Int
    let items: [PriceHistoryItem]
}
