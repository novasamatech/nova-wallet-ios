import Foundation
import Operation_iOS

private typealias PriceChartDataFilterPeriod = StakingRewardFiltersPeriod

extension PriceChartDataFilterPeriod {
    init?(from priceHistoryPeriod: PriceHistoryPeriod) {
        switch priceHistoryPeriod {
        case .week:
            self = .lastWeek
        case .month:
            self = .lastMonth
        case .year:
            self = .lastYear
        case .allTime:
            self = .allTime
        default:
            return nil
        }
    }
}

private struct PriceDataOptimizationMapping {
    let mappingValue: [PriceHistoryPeriod: Set<PriceHistoryPeriod>] = [
        .month: Set(arrayLiteral: .week),
        .allTime: Set(arrayLiteral: .year)
    ]
}

protocol PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: [PriceHistoryItem]]>
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
    ) -> CompoundOperationWrapper<[PriceHistoryItem]> {
        let fetchOperation = fetchOperationFactory.fetchPriceHistory(
            for: tokenId,
            currency: currency,
            period: period
        )

        let mapOperation: BaseOperation<[PriceHistoryItem]> = ClosureOperation {
            let priceHistory = try fetchOperation.extractNoCancellableResultData()

            return priceHistory.items
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
        in priceHistory: [PriceHistoryPeriod: [PriceHistoryItem]]
    ) -> [PriceHistoryPeriod: [PriceHistoryItem]] {
        var mutableHistory = priceHistory

        priceHistory.forEach { key, value in
            guard let periods = chartDataOptimizationMapping.mappingValue[key] else { return }

            periods.forEach { period in
                guard let startedAt = PriceChartDataFilterPeriod(from: period)?.interval.startTimestamp else {
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
        from longerHistory: [PriceHistoryItem],
        startedAt: UInt64
    ) -> [PriceHistoryItem] {
        var history: [PriceHistoryItem] = []

        for item in longerHistory.reversed() {
            guard item.startedAt >= startedAt else { break }

            history.append(item)
        }

        return history.reversed()
    }
}

// MARK: PriceChartDataOperationFactoryProtocol

extension PriceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: [PriceHistoryItem]]> {
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

        let mapOperation = ClosureOperation<[PriceHistoryPeriod: [PriceHistoryItem]]> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            var result: [PriceHistoryPeriod: [PriceHistoryItem]] = [:]

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
