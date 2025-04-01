import Foundation
import Operation_iOS

private struct PriceDataOptimizationMapping {
    let mappingValue: [PriceHistoryPeriod: Set<PriceHistoryPeriod>] = [
        .month: Set([.week]),
        .allTime: Set([.year])
    ]
}

protocol PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: PriceHistory]>
}

class PriceChartDataOperationFactory {
    private let fetchOperationFactory: CoingeckoOperationFactoryProtocol
    private let availablePeriods: [PriceHistoryPeriod]
    private let chartDataOptimizationMapping: PriceDataOptimizationMapping = .init()

    init(
        fetchOperationFactory: CoingeckoOperationFactoryProtocol,
        availablePeriods: [PriceHistoryPeriod]
    ) {
        self.fetchOperationFactory = fetchOperationFactory
        self.availablePeriods = availablePeriods
    }
}

// MARK: Private

private extension PriceChartDataOperationFactory {
    func createFetchHistoryWrapper(
        for tokenId: String,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory> {
        let fetchOperation = fetchOperationFactory.fetchPriceHistory(
            for: tokenId,
            currency: currency,
            period: period
        )

        let mapOperation: BaseOperation<PriceHistory> = ClosureOperation {
            let priceHistory = try fetchOperation.extractNoCancellableResultData()

            return priceHistory
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }

    func filterPeriods(
        _ periods: [PriceHistoryPeriod],
        mapping: PriceDataOptimizationMapping
    ) -> [PriceHistoryPeriod] {
        var mutablePeriods = periods

        periods.forEach { period in
            guard let innerPeriods = mapping.mappingValue[period] else { return }

            mutablePeriods.removeAll { innerPeriods.contains($0) }
        }

        return mutablePeriods
    }

    func fillPeriodGaps(
        in priceHistory: [PriceHistoryPeriod: PriceHistory]
    ) -> [PriceHistoryPeriod: PriceHistory] {
        var mutableHistory = priceHistory

        priceHistory.forEach { key, value in
            guard let periods = chartDataOptimizationMapping.mappingValue[key] else { return }

            periods.forEach { period in
                guard let startedAt = period.startedAt else {
                    return
                }

                mutableHistory[period] = createHistory(
                    from: value,
                    startedAt: UInt64(startedAt)
                )
            }
        }

        return mutableHistory
    }

    func createHistory(
        from longerHistory: PriceHistory,
        startedAt: UInt64
    ) -> PriceHistory {
        var historyItems: [PriceHistoryItem] = []

        for item in longerHistory.items.reversed() {
            guard item.startedAt >= startedAt else { break }

            historyItems.append(item)
        }

        return PriceHistory(
            currencyId: longerHistory.currencyId,
            items: historyItems.reversed()
        )
    }
}

// MARK: PriceChartDataOperationFactoryProtocol

extension PriceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: PriceHistory]> {
        let requestingPeriods = filterPeriods(
            availablePeriods,
            mapping: chartDataOptimizationMapping
        )

        let wrappers = requestingPeriods.map {
            createFetchHistoryWrapper(
                for: tokenId,
                currency: currency,
                period: $0
            )
        }

        let mapOperation = ClosureOperation<[PriceHistoryPeriod: PriceHistory]> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            var result: [PriceHistoryPeriod: PriceHistory] = [:]

            try zip(requestingPeriods, wrappers).forEach { pair in
                result[pair.0] = try pair.1.targetOperation.extractNoCancellableResultData()
            }

            result = fillPeriodGaps(in: result)

            return result
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrappers.flatMap(\.allOperations)
        )
    }
}
