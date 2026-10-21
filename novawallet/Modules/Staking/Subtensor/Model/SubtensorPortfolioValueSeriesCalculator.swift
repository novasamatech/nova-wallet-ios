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
        case .quarter, .year, .all:
            return .ninetyDays
        }
    }

    var sourceCoingeckoPeriod: PriceHistoryPeriod {
        switch self {
        case .day:
            return .day
        case .week, .month:
            return .month
        case .quarter, .year, .all:
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

    var isSlicedFromLongerSeries: Bool {
        switch self {
        case .day, .month, .all:
            return false
        case .week, .quarter, .year:
            return true
        }
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
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate)
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
        let taoFiat = TaoFiatSeries(history: histories.taoFiat, tolerance: histories.period.coverageTolerance)

        let completed = histories.portfolio.points.filter(\.completed).compactMap { point in
            valuePoint(for: point, taoFiat: taoFiat)
        }

        var points = gridPoints(from: completed, history: histories.portfolio, taoFiat: taoFiat, before: now)

        if
            portfolio.isFullyPriced,
            let totalTao = Decimal.fromSubstrateAmount(portfolio.pricedTaoValue, precision: precision),
            points.last.map({ $0.date < now }) ?? true {
            let livePrice = histories.taoFiat == nil
                ? reportedUsdPerTao(in: histories, now: now) ?? currentTaoPrice
                : currentTaoPrice

            points.append(SubtensorPortfolioValuePoint(date: now, taoValue: totalTao, fiatValue: totalTao * livePrice))
        }

        return SubtensorPortfolioValueSeries(
            points: points,
            changeInFiat: change(of: points, in: histories.portfolio)
        )
    }
}

private extension SubtensorPortfolioValueSeriesCalculator {
    /// The TAO fiat history prepared for nearest-instant lookups; absent when the fiat currency is USD
    /// and the backend's reported USD values are used as they are.
    struct TaoFiatSeries {
        let items: [PriceHistoryItem]?
        let times: [TimeInterval]
        let tolerance: TimeInterval

        init(history: PriceHistory?, tolerance: TimeInterval) {
            items = history?.items.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
            times = items?.map { TimeInterval($0.startedAt) } ?? []
            self.tolerance = tolerance
        }

        var isAvailable: Bool { items != nil }

        func price(at date: Date) -> Decimal? {
            guard let items else { return nil }

            return SubtensorPriceSeries.nearestIndex(
                to: date.timeIntervalSince1970,
                in: times,
                tolerance: tolerance
            ).map { items[$0].value }
        }
    }

    static func valuePoint(
        for point: BittensorApi.PortfolioHistoryPoint,
        taoFiat: TaoFiatSeries
    ) -> SubtensorPortfolioValuePoint? {
        guard
            let date = BittensorApi.instant(from: point.timestamp),
            let taoValue = try? BittensorApiDecimal.decimal(point.reportedValueTao) else {
            return nil
        }

        guard taoFiat.isAvailable else {
            return (try? BittensorApiDecimal.decimal(point.reportedValueUsd)).map { usdValue in
                SubtensorPortfolioValuePoint(date: date, taoValue: taoValue, fiatValue: usdValue)
            }
        }

        return taoFiat.price(at: date).map { price in
            SubtensorPortfolioValuePoint(date: date, taoValue: taoValue, fiatValue: taoValue * price)
        }
    }

    /// Walks the server window with the period step. Each instant takes the newest completed point
    /// at or before it that was not taken yet, carries the previous value when there is none, and is
    /// zero before the first completed point. Instants at or after `now` are left to the live point.
    static func gridPoints(
        from completed: [SubtensorPortfolioValuePoint],
        history: BittensorApi.PortfolioHistoryCollection,
        taoFiat: TaoFiatSeries,
        before now: Date
    ) -> [SubtensorPortfolioValuePoint] {
        guard
            let start = BittensorApi.instant(from: history.window.start),
            let end = BittensorApi.instant(from: history.window.end),
            start <= end else {
            return completed
        }

        let step = history.period.sampleStep
        let sorted = completed.sorted { $0.date < $1.date }
        var nextIndex = sorted.startIndex
        var last: SubtensorPortfolioValuePoint?
        var points: [SubtensorPortfolioValuePoint] = []
        var instant = start

        while instant <= end, instant < now {
            var matched: SubtensorPortfolioValuePoint?

            while nextIndex < sorted.endIndex, sorted[nextIndex].date <= instant {
                matched = sorted[nextIndex]
                nextIndex += 1
            }

            if let matched {
                points.append(matched)
                last = matched
            } else if let last {
                points.append(carriedPoint(last, at: instant, taoFiat: taoFiat))
            } else {
                points.append(SubtensorPortfolioValuePoint(date: instant, taoValue: 0, fiatValue: 0))
            }

            instant = instant.addingTimeInterval(step)
        }

        return points
    }

    /// Repeats the last known TAO total at a later instant, repriced with the TAO fiat history when it
    /// covers that instant and carried as is otherwise.
    static func carriedPoint(
        _ last: SubtensorPortfolioValuePoint,
        at instant: Date,
        taoFiat: TaoFiatSeries
    ) -> SubtensorPortfolioValuePoint {
        guard let price = taoFiat.price(at: instant) else {
            return SubtensorPortfolioValuePoint(date: instant, taoValue: last.taoValue, fiatValue: last.fiatValue)
        }

        return SubtensorPortfolioValuePoint(date: instant, taoValue: last.taoValue, fiatValue: last.taoValue * price)
    }

    static func reportedUsdPerTao(in histories: SubtensorPortfolioPriceHistories, now: Date) -> Decimal? {
        histories.portfolio.points.reversed().lazy.compactMap { point -> Decimal? in
            guard
                let date = BittensorApi.instant(from: point.timestamp),
                now.timeIntervalSince(date) <= histories.period.coverageTolerance,
                let taoValue = try? BittensorApiDecimal.decimal(point.reportedValueTao),
                let usdValue = try? BittensorApiDecimal.decimal(point.reportedValueUsd),
                taoValue > 0,
                usdValue > 0 else {
                return nil
            }

            return usdValue / taoValue
        }.first
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
