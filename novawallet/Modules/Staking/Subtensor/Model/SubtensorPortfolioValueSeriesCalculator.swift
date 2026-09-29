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
    let subnets: [SubtensorPriceHistory]
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

    var isSlicedFromLongerSeries: Bool {
        switch self {
        case .quarter:
            return true
        case .day, .week, .month, .year, .all:
            return false
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
        precision: Int16
    ) -> SubtensorPortfolioValueSeries {
        let period = histories.period
        let grid = taoFiatGrid(of: histories.taoFiat, period: period)

        guard
            portfolio.pricedTaoValue > 0,
            let totalTao = Decimal.fromSubstrateAmount(portfolio.pricedTaoValue, precision: precision),
            let newest = grid.last else {
            return SubtensorPortfolioValueSeries(points: [], changeInFiat: nil)
        }

        let holdings = createHoldings(
            of: portfolio,
            histories: histories.subnets,
            period: period,
            precision: precision
        )

        let pastPoints = grid.dropLast().compactMap { item in
            valuePoint(
                at: TimeInterval(item.startedAt),
                taoFiatPrice: item.value,
                holdings: holdings,
                tolerance: period.samplingInterval
            )
        }

        let newestPoint = SubtensorPortfolioValuePoint(
            date: Date(timeIntervalSince1970: TimeInterval(newest.startedAt)),
            taoValue: totalTao,
            fiatValue: totalTao * currentTaoPrice
        )

        let points = pastPoints + [newestPoint]

        return SubtensorPortfolioValueSeries(
            points: points,
            changeInFiat: SubtensorPriceSeries.change(of: points, over: period, date: \.date, value: \.fiatValue)
        )
    }
}

private extension SubtensorPortfolioValueSeriesCalculator {
    struct AnchoredHolding {
        let value: Decimal
        let newestTaoPerAlpha: Decimal
        let points: [SubtensorPricePoint]
        let times: [TimeInterval]
    }

    struct Holdings {
        let flatTao: Decimal
        let anchored: [AnchoredHolding]
    }

    static func createHoldings(
        of portfolio: SubtensorPortfolio,
        histories: [SubtensorPriceHistory],
        period: SubtensorPricePeriod,
        precision: Int16
    ) -> Holdings {
        let pointsByNetuid = histories.reduce(into: [UInt16: [SubtensorPricePoint]]()) { result, history in
            guard history.period == period, result[history.subnet.netuid] == nil else {
                return
            }

            result[history.subnet.netuid] = history.points
                .filter { $0.taoPerAlpha > 0 }
                .sorted { $0.date < $1.date }
        }

        var flatTao = portfolio.root?.taoValue.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) } ?? 0
        var anchored: [AnchoredHolding] = []

        for group in portfolio.subnets {
            guard
                let taoValue = group.taoValue,
                let value = Decimal.fromSubstrateAmount(taoValue, precision: precision) else {
                continue
            }

            guard
                let points = pointsByNetuid[group.netuid],
                let newestPoint = points.last else {
                flatTao += value
                continue
            }

            anchored.append(
                AnchoredHolding(
                    value: value,
                    newestTaoPerAlpha: newestPoint.taoPerAlpha,
                    points: points,
                    times: points.map(\.date.timeIntervalSince1970)
                )
            )
        }

        return Holdings(flatTao: flatTao, anchored: anchored)
    }

    static func taoFiatGrid(of history: PriceHistory, period: SubtensorPricePeriod) -> [PriceHistoryItem] {
        let items = history.items.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }

        return SubtensorPriceSeries.sliced(items, for: period) { item in
            Date(timeIntervalSince1970: TimeInterval(item.startedAt))
        }
    }

    static func valuePoint(
        at time: TimeInterval,
        taoFiatPrice: Decimal,
        holdings: Holdings,
        tolerance: TimeInterval
    ) -> SubtensorPortfolioValuePoint? {
        var taoValue = holdings.flatTao

        for holding in holdings.anchored {
            let index = SubtensorPriceSeries.nearestIndex(to: time, in: holding.times, tolerance: tolerance)

            guard let index else {
                return nil
            }

            taoValue += holding.value * holding.points[index].taoPerAlpha / holding.newestTaoPerAlpha
        }

        return SubtensorPortfolioValuePoint(
            date: Date(timeIntervalSince1970: time),
            taoValue: taoValue,
            fiatValue: taoValue * taoFiatPrice
        )
    }
}
