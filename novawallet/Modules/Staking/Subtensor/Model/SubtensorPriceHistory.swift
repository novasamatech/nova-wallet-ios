import Foundation

enum SubtensorPricePeriod: Equatable, CaseIterable {
    case day
    case week
    case month
    case quarter
    case year
    case all
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

enum SubtensorPriceData<Value: Equatable>: Equatable {
    case notListed
    case unavailable
    case available(Value)

    var availableValue: Value? {
        guard case let .available(value) = self else {
            return nil
        }

        return value
    }
}

struct SubtensorWeeklyPriceSummary: Equatable {
    let change: Decimal
    let sparkline: [Decimal]
}

struct SubtensorMonthlyPriceMetrics: Equatable {
    let changeInTao: Decimal?
    let meanTaoPerAlpha: Decimal?
    let thirtyDayRange: Decimal?
}
