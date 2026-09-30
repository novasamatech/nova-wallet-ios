import Foundation
import Operation_iOS

extension SubtensorPriceHistoryService {
    struct Fetcher {
        let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
        let taoPriceId: AssetModel.PriceId
        let operationQueue: OperationQueue
        let timeProvider: () -> TimeInterval
        let logger: LoggerProtocol
    }

    struct ListedValue<Value: Equatable> {
        let subnet: SubtensorSubnetRef
        let value: SubtensorPriceData<Value>
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

        return listed.mapValues { market in
            guard
                isCurrent(market, at: now),
                let percent = market.weekChangePercent else {
                return .unavailable
            }

            let summary = SubtensorWeeklyPriceSummary(
                change: (1 + percent / 100) / (1 + taoChange) - 1,
                sparkline: marketSparkline(of: market.weekSparkline, taoItems: taoItems)
            )

            return .available(summary)
        }
    }
}

private extension SubtensorPriceHistoryService {
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
}

extension SubtensorPriceHistoryService.Fetcher {
    func createPointsWrapper(
        alphaPriceId: String,
        currency: Currency,
        period: SubtensorPricePeriod
    ) -> CompoundOperationWrapper<[SubtensorPricePoint]> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: currency,
            period: period.coingeckoPeriod
        )

        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: currency,
            period: period.coingeckoPeriod
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

    func createChartValuesWrapper<Value: Equatable>(
        for listed: [SubtensorSubnetRef: String],
        period: SubtensorPricePeriod,
        evaluate: @escaping ([SubtensorPricePoint]) -> Value?
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: .usd,
            period: period.coingeckoPeriod
        )

        let subnets = listed.sorted { $0.key.netuid < $1.key.netuid }
        let fetcher = self
        let logger = logger

        let valuesOperation = OperationCombiningService<SubtensorPriceHistoryService.ListedValue<Value>>(
            operationManager: OperationManager(operationQueue: operationQueue),
            operationsPerBatch: SubtensorPriceHistoryService.alphaChartConcurrency
        ) {
            let taoItems: [PriceHistoryItem]

            do {
                taoItems = try taoOperation.extractNoCancellableResultData().items
            } catch {
                logger.warning("Subtensor TAO price history unavailable: \(error)")
                return []
            }

            return subnets.map { subnet, alphaPriceId in
                fetcher.createChartValueWrapper(
                    for: subnet,
                    alphaPriceId: alphaPriceId,
                    period: period,
                    taoItems: taoItems,
                    evaluate: evaluate
                )
            }
        }.longrunOperation()

        valuesOperation.addDependency(taoOperation)

        let resultOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<Value>]> {
            try valuesOperation.extractNoCancellableResultData().reduce(into: [:]) { result, listedValue in
                result[listedValue.subnet] = listedValue.value
            }
        }

        resultOperation.addDependency(valuesOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [taoOperation, valuesOperation]
        )
    }

    func createMarketChangesWrapper(
        for listed: [SubtensorSubnetRef: SubtensorSubnetMarket]
    ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
        let taoOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: taoPriceId,
            currency: .usd,
            period: SubtensorPricePeriod.week.coingeckoPeriod
        )

        let timeProvider = timeProvider
        let logger = logger

        let changesOperation = ClosureOperation<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
            do {
                let tao = try taoOperation.extractNoCancellableResultData()

                return SubtensorPriceHistoryService.marketChanges(
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

private extension SubtensorPriceHistoryService.Fetcher {
    func createChartValueWrapper<Value: Equatable>(
        for subnet: SubtensorSubnetRef,
        alphaPriceId: String,
        period: SubtensorPricePeriod,
        taoItems: [PriceHistoryItem],
        evaluate: @escaping ([SubtensorPricePoint]) -> Value?
    ) -> CompoundOperationWrapper<SubtensorPriceHistoryService.ListedValue<Value>> {
        let alphaOperation = coingeckoOperationFactory.fetchPriceHistory(
            for: alphaPriceId,
            currency: .usd,
            period: period.coingeckoPeriod
        )

        let logger = logger

        let valueOperation = ClosureOperation<SubtensorPriceHistoryService.ListedValue<Value>> {
            do {
                let alpha = try alphaOperation.extractNoCancellableResultData()

                let points = SubtensorPriceSeries.matchedPoints(
                    alpha: alpha.items,
                    tao: taoItems,
                    tolerance: period.samplingInterval
                )

                guard let value = evaluate(points) else {
                    return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .unavailable)
                }

                return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .available(value))
            } catch {
                logger.warning("Subtensor price history of netuid \(subnet.netuid) unavailable: \(error)")

                return SubtensorPriceHistoryService.ListedValue(subnet: subnet, value: .unavailable)
            }
        }

        valueOperation.addDependency(alphaOperation)

        return CompoundOperationWrapper(targetOperation: valueOperation, dependencies: [alphaOperation])
    }
}
