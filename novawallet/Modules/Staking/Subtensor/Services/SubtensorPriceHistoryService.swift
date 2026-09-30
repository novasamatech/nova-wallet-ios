import Foundation
import Operation_iOS

final class SubtensorPriceHistoryService {
    static let alphaChartConcurrency = 4
    static let sparklineMaxCount = 48
    static let marketStalenessLimit = TimeInterval(24).secondsFromHours

    let marketsService: SubtensorSubnetMarketsServiceProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let taoPriceId: AssetModel.PriceId
    let operationQueue: OperationQueue
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    init(
        marketsService: SubtensorSubnetMarketsServiceProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        taoPriceId: AssetModel.PriceId,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        logger: LoggerProtocol = Logger.shared
    ) {
        self.marketsService = marketsService
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.taoPriceId = taoPriceId
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

extension SubtensorPriceHistoryService {
    static func makeHistory(
        subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        points: [SubtensorPricePoint]
    ) -> SubtensorPriceHistory {
        let periodPoints = SubtensorPriceSeries.sliced(points, for: period, date: \.date)

        return SubtensorPriceHistory(
            subnet: subnet,
            period: period,
            points: periodPoints,
            changeInTao: SubtensorPriceSeries.change(
                of: periodPoints,
                over: period,
                date: \.date,
                value: \.taoPerAlpha
            ),
            changeInFiat: SubtensorPriceSeries.change(
                of: periodPoints,
                over: period,
                date: \.date,
                value: \.fiatPerAlpha
            )
        )
    }

    static func monthlyMetrics(of points: [SubtensorPricePoint]) -> SubtensorMonthlyPriceMetrics? {
        guard let change = SubtensorPriceSeries.change(
            of: points,
            over: .month,
            date: \.date,
            value: \.taoPerAlpha
        ) else {
            return nil
        }

        let values = points.map(\.taoPerAlpha)

        return SubtensorMonthlyPriceMetrics(
            changeInTao: change,
            meanTaoPerAlpha: values.reduce(Decimal.zero, +) / Decimal(values.count),
            thirtyDayRange: range(of: values)
        )
    }

    static func range(of values: [Decimal]) -> Decimal? {
        guard let minimum = values.min(), let maximum = values.max(), maximum + minimum > 0 else {
            return nil
        }

        return (maximum - minimum) / (maximum + minimum)
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

private extension SubtensorPriceHistoryService {
    static func listedMarkets(
        for subnets: [SubtensorSubnetRef],
        in markets: SubtensorSubnetMarkets
    ) -> [SubtensorSubnetRef: SubtensorSubnetMarket] {
        subnets.reduce(into: [:]) { result, subnet in
            result[subnet] = markets.market(for: subnet.netuid)
        }
    }

    var fetcher: Fetcher {
        Fetcher(
            coingeckoOperationFactory: coingeckoOperationFactory,
            taoPriceId: taoPriceId,
            operationQueue: operationQueue,
            timeProvider: timeProvider,
            logger: logger
        )
    }

    func createPriceDataWrapper<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listedValuesWrapper: @escaping ([SubtensorSubnetRef: SubtensorSubnetMarket])
            -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]>
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let marketsWrapper = marketsService.createMarketsWrapper()

        let pricesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedMarkets(for: subnets, in: markets)

                let valuesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
                    listed.isEmpty ? .createWithResult([:]) : listedValuesWrapper(listed)

                let resultOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
                    let values = try valuesWrapper.targetOperation.extractNoCancellableResultData()

                    return Self.priceData(for: subnets, listed: listed, values: values)
                }

                resultOperation.addDependency(valuesWrapper.targetOperation)

                return valuesWrapper.insertingTail(operation: resultOperation)
            }

        pricesWrapper.addDependency(wrapper: marketsWrapper)

        return pricesWrapper.insertingHead(operations: marketsWrapper.allOperations)
    }
}

extension SubtensorPriceHistoryService: SubtensorPriceHistoryServiceProtocol {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult> {
        let marketsWrapper = marketsService.createMarketsWrapper()
        let fetcher = fetcher

        let pointsWrapper: CompoundOperationWrapper<[SubtensorPricePoint]?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let markets = try marketsWrapper.targetOperation.extractNoCancellableResultData()

            guard let alphaPriceId = markets.market(for: subnet.netuid)?.coingeckoId else {
                return nil
            }

            return fetcher.createPointsWrapper(alphaPriceId: alphaPriceId, currency: currency, period: period)
        }

        pointsWrapper.addDependency(wrapper: marketsWrapper)

        let resultOperation = ClosureOperation<SubtensorPriceHistoryResult> {
            guard let points = try pointsWrapper.targetOperation.extractNoCancellableResultData() else {
                return .notListed
            }

            return .available(Self.makeHistory(subnet: subnet, period: period, points: points))
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
        let fetcher = fetcher

        return createPriceDataWrapper(for: subnets) { listed in
            fetcher.createMarketChangesWrapper(for: listed)
        }
    }
}
