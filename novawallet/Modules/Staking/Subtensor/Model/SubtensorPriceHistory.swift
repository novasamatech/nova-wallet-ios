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

extension SubtensorPriceHistory {
    func replacingLatest(with latest: SubtensorPricePoint) -> SubtensorPriceHistory {
        guard let first = points.first else {
            return self
        }

        let updatedPoints = points.count > 1 ? points.dropLast() + [latest] : [latest]

        return SubtensorPriceHistory(
            subnet: subnet,
            period: period,
            points: updatedPoints,
            changeInTao: changeInTao.flatMap { _ in
                Self.change(from: first.taoPerAlpha, to: latest.taoPerAlpha)
            },
            changeInFiat: changeInFiat.flatMap { _ in
                Self.change(from: first.fiatPerAlpha, to: latest.fiatPerAlpha)
            }
        )
    }
}

private extension SubtensorPriceHistory {
    static func change(from first: Decimal, to last: Decimal) -> Decimal? {
        first > 0 ? (last - first) / first : nil
    }
}
