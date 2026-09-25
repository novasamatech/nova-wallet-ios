import Foundation

enum SubtensorPricePeriod: Equatable, CaseIterable {
    case day
    case week
    case month
    case quarter
    case year
}

struct SubtensorPricePoint: Equatable {
    let date: Date
    let taoPerAlpha: Decimal
    let fiatPerAlpha: Decimal
}

struct SubtensorPriceHistory: Equatable {
    let subnet: SubtensorSubnetRef
    let period: SubtensorPricePeriod
    let points: [SubtensorPricePoint]
    let changeInTao: Decimal?
    let changeInFiat: Decimal?
}

enum SubtensorPriceHistoryResult: Equatable {
    case available(SubtensorPriceHistory)
    case notListed
}
