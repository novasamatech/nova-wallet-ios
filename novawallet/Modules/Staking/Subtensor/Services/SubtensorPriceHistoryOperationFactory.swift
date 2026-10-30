import Foundation
import Operation_iOS

final class SubtensorPriceHistoryOperationFactory {
    static let sparklineMaxCount = 48
    static let marketStalenessLimit = TimeInterval(24).secondsFromHours

    let marketsOperationFactory: SubtensorSubnetMarketsOperationFactoryProtocol
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let taoPriceId: AssetModel.PriceId
    let operationQueue: OperationQueue
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    init(
        marketsOperationFactory: SubtensorSubnetMarketsOperationFactoryProtocol,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        taoPriceId: AssetModel.PriceId,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        logger: LoggerProtocol = Logger.shared
    ) {
        self.marketsOperationFactory = marketsOperationFactory
        self.apiOperationFactory = apiOperationFactory
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.taoPriceId = taoPriceId
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

extension SubtensorPriceHistoryOperationFactory {
    static func makeHistory(
        subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        points: [SubtensorPricePoint],
        registrationDate: Date?
    ) -> SubtensorPriceHistory {
        let registrationDate = registrationDate ?? .distantPast
        let registeredPoints = points.filter { $0.date >= registrationDate }
        let periodPoints = SubtensorPriceSeries.sliced(registeredPoints, for: period, date: \.date)

        let coversPeriod = periodPoints.last
            .flatMap { period.startDate(endingAt: $0.date) }
            .map { registrationDate.timeIntervalSince($0) <= period.coverageTolerance } ?? true

        return SubtensorPriceHistory(
            subnet: subnet,
            period: period,
            points: periodPoints,
            changeInTao: coversPeriod
                ? SubtensorPriceSeries.change(of: periodPoints, over: period, date: \.date, value: \.taoPerAlpha)
                : nil
        )
    }

    static func sparkline(of values: [Decimal]) -> [Decimal] {
        guard values.count > sparklineMaxCount else {
            return values
        }

        let step = (values.count + sparklineMaxCount - 1) / sparklineMaxCount
        let lastIndex = values.count - 1

        return stride(from: lastIndex % step, through: lastIndex, by: step).map { values[$0] }
    }

    static func priceData<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listed: [SubtensorSubnetRef: SubtensorSubnetMarket],
        values: [SubtensorSubnetRef: SubtensorPriceData<Value>]
    ) -> [SubtensorSubnetRef: SubtensorPriceData<Value>] {
        subnets.reduce(into: [:]) { result, subnet in
            guard listed[subnet] != nil else {
                result[subnet] = .notListed
                return
            }

            result[subnet] = values[subnet] ?? .unavailable
        }
    }
}

private extension SubtensorPriceHistoryOperationFactory {
    static func listedMarkets(
        for subnets: [SubtensorSubnetRef],
        in markets: SubtensorSubnetMarkets
    ) -> [SubtensorSubnetRef: SubtensorSubnetMarket] {
        subnets.reduce(into: [:]) { result, subnet in
            result[subnet] = markets.byNetuid[subnet.netuid]
        }
    }

    func createPriceDataWrapper<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listedValuesWrapper: @escaping ([SubtensorSubnetRef: SubtensorSubnetMarket])
            -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]>
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let marketsWrapper = marketsOperationFactory.createMarketsWrapper()

        let pricesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedMarkets(for: subnets, in: markets)

                let valuesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
                    listed.isEmpty ? .createWithResult([:]) : listedValuesWrapper(listed)

                return valuesWrapper.mapped { Self.priceData(for: subnets, listed: listed, values: $0) }
            }

        pricesWrapper.addDependency(wrapper: marketsWrapper)

        return pricesWrapper.insertingHead(operations: marketsWrapper.allOperations)
    }

    static func marketChanges(
        of listed: [SubtensorSubnetRef: SubtensorSubnetMarket],
        taoWeekItems: [PriceHistoryItem],
        at now: TimeInterval
    ) -> [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>] {
        let taoItems = taoWeekItems.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoDate: (PriceHistoryItem) -> Date = { Date(timeIntervalSince1970: TimeInterval($0.startedAt)) }

        guard
            let taoChange = SubtensorPriceSeries.change(of: taoItems, over: .week, date: taoDate, value: \.value),
            1 + taoChange > 0 else {
            return listed.mapValues { _ in .unavailable }
        }

        return listed.reduce(into: [:]) { result, item in
            let (subnet, market) = item

            guard isCurrent(market, at: now), let percent = market.weekChangePercent else {
                result[subnet] = .unavailable
                return
            }

            let summary = SubtensorWeeklyPriceSummary(
                change: (1 + percent / 100) / (1 + taoChange) - 1,
                sparkline: marketSparkline(of: market.weekSparkline, taoItems: taoItems)
            )

            result[subnet] = .available(summary)
        }
    }

    static func isCurrent(_ market: SubtensorSubnetMarket, at now: TimeInterval) -> Bool {
        guard let lastUpdated = market.lastUpdated else {
            return false
        }

        return now - lastUpdated.timeIntervalSince1970 <= marketStalenessLimit
    }

    static func marketSparkline(of prices: [Decimal?], taoItems: [PriceHistoryItem]) -> [Decimal] {
        guard prices.count > 1, let lastTaoItem = taoItems.last else {
            return []
        }

        let end = Date(timeIntervalSince1970: TimeInterval(lastTaoItem.startedAt))

        guard let start = SubtensorPricePeriod.week.startDate(endingAt: end) else {
            return []
        }

        let step = end.timeIntervalSince(start) / TimeInterval(prices.count - 1)

        let alphaItems = prices.enumerated().compactMap { index, price -> PriceHistoryItem? in
            let time = start.timeIntervalSince1970 + step * TimeInterval(index)

            guard let price, time >= 0 else {
                return nil
            }

            return PriceHistoryItem(startedAt: UInt64(time.rounded()), value: price)
        }

        let points = SubtensorPriceSeries.matchedPoints(
            alpha: alphaItems,
            tao: taoItems,
            tolerance: SubtensorPricePeriod.week.samplingInterval
        )

        return sparkline(of: points.map(\.taoPerAlpha))
    }

    func createPointsWrapper(
        alphaPriceId: String,
        currency: Currency,
        period: SubtensorPricePeriod
    ) -> CompoundOperationWrapper<[SubtensorPricePoint]> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: currency,
            period: period.sourceCoingeckoPeriod
        )

        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: currency,
            period: period.sourceCoingeckoPeriod
        )

        let pointsOperation = ClosureOperation<[SubtensorPricePoint]> {
            let alpha = try alphaOperation.extractNoCancellableResultData()
            let tao = try taoOperation.extractNoCancellableResultData()

            return SubtensorPriceSeries.matchedPoints(
                alpha: alpha.items,
                tao: tao.items,
                tolerance: period.samplingInterval
            )
        }

        pointsOperation.addDependency(alphaOperation)
        pointsOperation.addDependency(taoOperation)

        return CompoundOperationWrapper(targetOperation: pointsOperation, dependencies: [alphaOperation, taoOperation])
    }

    func createMarketChangesWrapper(
        for listed: [SubtensorSubnetRef: SubtensorSubnetMarket]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(for: taoPriceId, currency: .usd, period: .week)

        let timeProvider = timeProvider
        let logger = logger

        let changesOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
            do {
                let tao = try taoOperation.extractNoCancellableResultData()

                return SubtensorPriceHistoryOperationFactory.marketChanges(
                    of: listed,
                    taoWeekItems: tao.items,
                    at: timeProvider()
                )
            } catch {
                logger.warning("Subtensor TAO price history unavailable: \(error)")
                return [:]
            }
        }

        changesOperation.addDependency(taoOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [taoOperation])
    }
}

extension SubtensorPriceHistoryOperationFactory: SubtensorPriceHistoryOperationFactoryProtocol {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency,
        registrationDate: Date?
    ) -> CompoundOperationWrapper<SubtensorPriceHistory?> {
        let marketsWrapper = marketsOperationFactory.createMarketsWrapper()

        let pointsWrapper: CompoundOperationWrapper<[SubtensorPricePoint]?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()

            guard let alphaPriceId = markets.byNetuid[subnet.netuid]?.coingeckoId else {
                return nil
            }

            return self.createPointsWrapper(alphaPriceId: alphaPriceId, currency: currency, period: period)
        }

        pointsWrapper.addDependency(wrapper: marketsWrapper)

        let resultOperation = ClosureOperation<SubtensorPriceHistory?> {
            guard let points = try pointsWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            return Self.makeHistory(subnet: subnet, period: period, points: points, registrationDate: registrationDate)
        }

        resultOperation.addDependency(pointsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: marketsWrapper.allOperations + pointsWrapper.allOperations
        )
    }

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        createPriceDataWrapper(for: subnets) { listed in
            self.createMarketChangesWrapper(for: listed)
        }
    }
}
