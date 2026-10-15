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
    let portfolio: BittensorApi.PortfolioHistoryCollection
    let taoFiat: PriceHistory?
}

extension SubtensorPricePeriod {
    var portfolioHistoryPeriod: BittensorApi.PortfolioHistoryPeriod {
        switch self {
        case .day:
            return .oneDay
        case .week:
            return .sevenDays
        case .month:
            return .thirtyDays
        case .quarter, .all:
            return .ninetyDays
        }
    }

    var coingeckoPeriod: PriceHistoryPeriod {
        switch self {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .quarter, .all:
            return .allTime
        }
    }

    var samplingInterval: TimeInterval {
        switch self {
        case .day:
            return 5 * 60
        case .week, .month:
            return 60 * 60
        case .quarter, .all:
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
        case .quarter, .all:
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
            return calendar.date(byAdding: .day, value: -90, to: endDate)
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
        let taoFiat = histories.taoFiat?.items.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoFiatTimes = taoFiat?.map { TimeInterval($0.startedAt) } ?? []

        var points = histories.portfolio.points.filter(\.completed).compactMap { point in
            valuePoint(
                for: point,
                taoFiat: taoFiat,
                taoFiatTimes: taoFiatTimes,
                tolerance: histories.period.coverageTolerance
            )
        }

        if
            portfolio.isFullyPriced,
            let totalTao = Decimal.fromSubstrateAmount(portfolio.pricedTaoValue, precision: precision),
            points.last.map({ $0.date < now }) ?? true {
            let fiatValue = totalTao * currentTaoPrice
            points.append(SubtensorPortfolioValuePoint(date: now, taoValue: totalTao, fiatValue: fiatValue))
        }

        return SubtensorPortfolioValueSeries(
            points: points,
            changeInFiat: change(of: points, in: histories.portfolio)
        )
    }
}

private extension SubtensorPortfolioValueSeriesCalculator {
    static func valuePoint(
        for point: BittensorApi.PortfolioHistoryPoint,
        taoFiat: [PriceHistoryItem]?,
        taoFiatTimes: [TimeInterval],
        tolerance: TimeInterval
    ) -> SubtensorPortfolioValuePoint? {
        guard
            let date = BittensorApi.instant(from: point.timestamp),
            let taoValue = try? BittensorApiDecimal.decimal(point.reportedValueTao) else {
            return nil
        }

        guard let taoFiat else {
            return (try? BittensorApiDecimal.decimal(point.reportedValueUsd)).map { usdValue in
                SubtensorPortfolioValuePoint(date: date, taoValue: taoValue, fiatValue: usdValue)
            }
        }

        let time = date.timeIntervalSince1970

        return SubtensorPriceSeries.nearestIndex(to: time, in: taoFiatTimes, tolerance: tolerance).map { index in
            SubtensorPortfolioValuePoint(date: date, taoValue: taoValue, fiatValue: taoValue * taoFiat[index].value)
        }
    }

    static func change(
        of points: [SubtensorPortfolioValuePoint],
        in history: BittensorApi.PortfolioHistoryCollection
    ) -> Decimal? {
        guard
            points.count > 1,
            let first = points.first,
            let last = points.last,
            first.fiatValue > 0,
            let windowStart = BittensorApi.instant(from: history.window.start),
            first.date.timeIntervalSince(windowStart) <= 2 * history.period.sampleStep else {
            return nil
        }

        return (last.fiatValue - first.fiatValue) / first.fiatValue
    }
}
