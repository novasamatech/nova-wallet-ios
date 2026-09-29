import Foundation
import Operation_iOS

enum SubtensorWeeklyChangeSource {
    case alphaMarketCharts
    case subnetMarkets
}

final class SubtensorPriceHistoryService {
    static let weeklyChangeSource = SubtensorWeeklyChangeSource.alphaMarketCharts
    static let alphaChartConcurrency = 4
    static let subnetMarketsCategory = "bittensor-subnets"
    static let subnetMarketsPageSize = 250
    static let sparklineMaxCount = 48

    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let taoPriceId: AssetModel.PriceId
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        taoPriceId: AssetModel.PriceId,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.earnConfigProvider = earnConfigProvider
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.taoPriceId = taoPriceId
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorPriceHistoryService {
    static func coingeckoId(in config: SubtensorEarnConfig, for subnet: SubtensorSubnetRef) -> String? {
        let rawId = config.subnetEntry(for: subnet)?.coingeckoId

        guard
            let coingeckoId = rawId?.trimmingCharacters(in: .whitespacesAndNewlines),
            !coingeckoId.isEmpty,
            coingeckoId.unicodeScalars.allSatisfy({ coingeckoIdCharacters.contains($0) }) else {
            return nil
        }

        return coingeckoId
    }

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

    static func weeklySummary(of points: [SubtensorPricePoint]) -> SubtensorWeeklyPriceSummary? {
        guard let change = SubtensorPriceSeries.change(
            of: points,
            over: .week,
            date: \.date,
            value: \.taoPerAlpha
        ) else {
            return nil
        }

        return SubtensorWeeklyPriceSummary(change: change, sparkline: sparkline(of: points.map(\.taoPerAlpha)))
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
        listed: [SubtensorSubnetRef: String],
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
    static let coingeckoIdCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    static func listedIds(
        for subnets: [SubtensorSubnetRef],
        in config: SubtensorEarnConfig
    ) -> [SubtensorSubnetRef: String] {
        subnets.reduce(into: [:]) { result, subnet in
            result[subnet] = coingeckoId(in: config, for: subnet)
        }
    }

    var fetcher: Fetcher {
        Fetcher(
            coingeckoOperationFactory: coingeckoOperationFactory,
            taoPriceId: taoPriceId,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createPriceDataWrapper<Value: Equatable>(
        for subnets: [SubtensorSubnetRef],
        listedValuesWrapper: @escaping ([SubtensorSubnetRef: String])
            -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]>
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let configWrapper = earnConfigProvider.createConfigWrapper()

        let pricesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let config = try configWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedIds(for: subnets, in: config)

                let valuesWrapper: CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> =
                    listed.isEmpty ? .createWithResult([:]) : listedValuesWrapper(listed)

                let resultOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
                    let values = try valuesWrapper.targetOperation.extractNoCancellableResultData()

                    return Self.priceData(for: subnets, listed: listed, values: values)
                }

                resultOperation.addDependency(valuesWrapper.targetOperation)

                return valuesWrapper.insertingTail(operation: resultOperation)
            }

        pricesWrapper.addDependency(wrapper: configWrapper)

        return pricesWrapper.insertingHead(operations: configWrapper.allOperations)
    }
}

extension SubtensorPriceHistoryService: SubtensorPriceHistoryServiceProtocol {
    func createHistoryWrapper(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryResult> {
        let configWrapper = earnConfigProvider.createConfigWrapper()
        let fetcher = fetcher

        let pointsWrapper: CompoundOperationWrapper<[SubtensorPricePoint]?> = OperationCombiningService.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            guard let alphaPriceId = Self.coingeckoId(in: config, for: subnet) else {
                return nil
            }

            return fetcher.createPointsWrapper(alphaPriceId: alphaPriceId, currency: currency, period: period)
        }

        pointsWrapper.addDependency(wrapper: configWrapper)

        let resultOperation = ClosureOperation<SubtensorPriceHistoryResult> {
            guard let points = try pointsWrapper.targetOperation.extractNoCancellableResultData() else {
                return .notListed
            }

            return .available(Self.makeHistory(subnet: subnet, period: period, points: points))
        }

        resultOperation.addDependency(pointsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: configWrapper.allOperations + pointsWrapper.allOperations
        )
    }

    func createWeeklyChangesWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let fetcher = fetcher

        return createPriceDataWrapper(for: subnets) { listed in
            switch Self.weeklyChangeSource {
            case .alphaMarketCharts:
                return fetcher.createChartValuesWrapper(
                    for: listed,
                    period: .week,
                    evaluate: SubtensorPriceHistoryService.weeklySummary(of:)
                )
            case .subnetMarkets:
                return fetcher.createSubnetMarketChangesWrapper(for: listed)
            }
        }
    }

    func createMonthlyMetricsWrapper(
        for subnets: [SubtensorSubnetRef]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorMonthlyPriceMetrics>]> {
        let fetcher = fetcher

        return createPriceDataWrapper(for: subnets) { listed in
            fetcher.createChartValuesWrapper(
                for: listed,
                period: .month,
                evaluate: SubtensorPriceHistoryService.monthlyMetrics(of:)
            )
        }
    }
}
