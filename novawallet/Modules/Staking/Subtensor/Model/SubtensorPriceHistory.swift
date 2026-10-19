import Foundation

enum SubtensorPricePeriod: Equatable {
    case day
    case week
    case month
    case quarter
    case year
    case all

    static let selectable: [SubtensorPricePeriod] = [.day, .week, .month, .quarter]
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
