import BigInt
import Foundation
import SubstrateSdk

struct SubtensorPortfolioValuePoint: Equatable {
    let date: Date
    let taoValue: Decimal
    let fiatValue: Decimal
}

struct SubtensorPortfolioValueSeries: Equatable {
    let points: [SubtensorPortfolioValuePoint]
    let changeInFiat: Decimal?
}

struct SubtensorPortfolioPriceHistories: Equatable {
    let period: SubtensorPricePeriod
    let taoFiat: PriceHistory
    let stake: SubtensorPortfolioStakeHistory
}

extension SubtensorPricePeriod {
    var coingeckoPeriod: PriceHistoryPeriod {
        switch self {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .quarter, .year:
            return .year
        case .all:
            return .allTime
        }
    }

    var samplingInterval: TimeInterval {
        switch self {
        case .day:
            return 5 * 60
        case .week, .month:
            return 60 * 60
        case .quarter, .year, .all:
            return 24 * 60 * 60
        }
    }

    var coverageTolerance: TimeInterval {
        2 * samplingInterval
    }

    var sourcePeriod: SubtensorPricePeriod {
        switch self {
        case .day:
            return .day
        case .week, .month:
            return .month
        case .quarter, .year, .all:
            return .all
        }
    }

    var isSlicedFromLongerSeries: Bool {
        self != sourcePeriod
    }

    func startDate(endingAt endDate: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: endDate)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate)
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: endDate)
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: endDate)
        case .year:
            return calendar.date(byAdding: .day, value: -365, to: endDate)
        case .all:
            return nil
        }
    }
}

enum SubtensorPriceSeries {
    static func nearestIndex(to time: TimeInterval, in sortedTimes: [TimeInterval], tolerance: TimeInterval) -> Int? {
        var lowerBound = 0
        var upperBound = sortedTimes.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2

            if sortedTimes[middle] < time {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        let nearest = [lowerBound - 1, lowerBound]
            .filter { sortedTimes.indices.contains($0) }
            .min { abs(sortedTimes[$0] - time) < abs(sortedTimes[$1] - time) }

        guard let nearest, abs(sortedTimes[nearest] - time) <= tolerance else {
            return nil
        }

        return nearest
    }

    static func change<T>(
        of sortedItems: [T],
        over period: SubtensorPricePeriod,
        date: (T) -> Date,
        value: (T) -> Decimal
    ) -> Decimal? {
        guard
            sortedItems.count > 1,
            let first = sortedItems.first,
            let last = sortedItems.last,
            value(first) > 0 else {
            return nil
        }

        if let start = period.startDate(endingAt: date(last)),
           date(first).timeIntervalSince(start) > period.coverageTolerance {
            return nil
        }

        return (value(last) - value(first)) / value(first)
    }

    static func sliced<T>(_ sortedItems: [T], for period: SubtensorPricePeriod, date: (T) -> Date) -> [T] {
        guard
            period.isSlicedFromLongerSeries,
            let last = sortedItems.last,
            let start = period.startDate(endingAt: date(last)) else {
            return sortedItems
        }

        return sortedItems.filter { date($0) >= start }
    }

    static func matchedPoints(
        alpha: [PriceHistoryItem],
        tao: [PriceHistoryItem],
        tolerance: TimeInterval
    ) -> [SubtensorPricePoint] {
        let sortedTao = tao.sorted { $0.startedAt < $1.startedAt }
        let taoTimes = sortedTao.map { TimeInterval($0.startedAt) }

        return alpha.sorted { $0.startedAt < $1.startedAt }.compactMap { item in
            let time = TimeInterval(item.startedAt)

            guard
                let index = nearestIndex(to: time, in: taoTimes, tolerance: tolerance),
                sortedTao[index].value > 0 else {
                return nil
            }

            return SubtensorPricePoint(
                date: Date(timeIntervalSince1970: time),
                taoPerAlpha: item.value / sortedTao[index].value,
                fiatPerAlpha: item.value
            )
        }
    }
}

enum SubtensorPortfolioValueSeriesCalculator {
    static func calculate(
        portfolio: SubtensorPortfolio,
        histories: SubtensorPortfolioPriceHistories,
        currentTaoPrice: Decimal,
        precision: Int16,
        now: Date = Date()
    ) -> SubtensorPortfolioValueSeries {
        let grid = taoFiatGrid(of: histories.taoFiat)
        let times = grid.map { TimeInterval($0.startedAt) }
        let tolerance = histories.period.coverageTolerance

        let livePoint = createLivePoint(
            of: portfolio,
            currentTaoPrice: currentTaoPrice,
            precision: precision,
            at: now
        )

        var points = histories.stake.points.compactMap { point -> SubtensorPortfolioValuePoint? in
            guard point.isCompleted || livePoint == nil else {
                return nil
            }

            return valuePoint(for: point, grid: grid, times: times, tolerance: tolerance)
        }

        if let livePoint, points.last.map({ $0.date < livePoint.date }) ?? true {
            points.append(livePoint)
        }

        return SubtensorPortfolioValueSeries(
            points: points,
            changeInFiat: change(of: points, stake: histories.stake)
        )
    }
}

private extension SubtensorPortfolioValueSeriesCalculator {
    static func createLivePoint(
        of portfolio: SubtensorPortfolio,
        currentTaoPrice: Decimal,
        precision: Int16,
        at date: Date
    ) -> SubtensorPortfolioValuePoint? {
        guard
            portfolio.isFullyPriced,
            let totalTao = Decimal.fromSubstrateAmount(portfolio.pricedTaoValue, precision: precision) else {
            return nil
        }

        return SubtensorPortfolioValuePoint(date: date, taoValue: totalTao, fiatValue: totalTao * currentTaoPrice)
    }

    static func taoFiatGrid(of history: PriceHistory) -> [PriceHistoryItem] {
        history.items.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
    }

    static func valuePoint(
        for point: SubtensorPortfolioStakePoint,
        grid: [PriceHistoryItem],
        times: [TimeInterval],
        tolerance: TimeInterval
    ) -> SubtensorPortfolioValuePoint? {
        let time = point.date.timeIntervalSince1970

        guard let index = SubtensorPriceSeries.nearestIndex(to: time, in: times, tolerance: tolerance) else {
            return nil
        }

        return SubtensorPortfolioValuePoint(
            date: point.date,
            taoValue: point.taoValue,
            fiatValue: point.taoValue * grid[index].value
        )
    }

    static func change(
        of points: [SubtensorPortfolioValuePoint],
        stake: SubtensorPortfolioStakeHistory
    ) -> Decimal? {
        guard
            points.count > 1,
            let first = points.first,
            let last = points.last,
            first.fiatValue > 0,
            first.date.timeIntervalSince(stake.windowStart) <= stake.coverageTolerance else {
            return nil
        }

        return (last.fiatValue - first.fiatValue) / first.fiatValue
    }
}
