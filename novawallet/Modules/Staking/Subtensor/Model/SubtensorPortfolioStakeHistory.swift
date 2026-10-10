import Foundation

struct SubtensorPortfolioStakePoint: Equatable {
    let date: Date
    let taoValue: Decimal
    let usdValue: Decimal
    let isCompleted: Bool
}

struct SubtensorPortfolioStakeHistory: Equatable {
    let period: SubtensorPricePeriod
    let windowStart: Date
    let windowEnd: Date
    let points: [SubtensorPortfolioStakePoint]

    // A series whose first sample sits further than two server steps after the window start
    // does not cover the period, so the header change is hidden rather than computed from a partial span.
    var coverageTolerance: TimeInterval {
        2 * period.portfolioHistoryStep
    }
}

extension SubtensorPricePeriod {
    var portfolioHistoryPeriod: BittensorApi.PortfolioHistoryPeriod? {
        switch self {
        case .day:
            return .oneDay
        case .week:
            return .sevenDays
        case .month:
            return .thirtyDays
        case .quarter:
            return .ninetyDays
        case .year, .all:
            return nil
        }
    }

    var portfolioHistoryStep: TimeInterval {
        switch self {
        case .day, .week:
            return 60 * 60
        case .month:
            return 4 * 60 * 60
        case .quarter:
            return 8 * 60 * 60
        case .year, .all:
            return 24 * 60 * 60
        }
    }
}
