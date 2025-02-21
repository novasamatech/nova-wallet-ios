import Foundation
import Operation_iOS

protocol PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: [PriceHistoryItem]]>
}

class PriceChartDataOperationFactory {
    let fetchOperationFactory: CoingeckoOperationFactoryProtocol
    let availablePeriods: [PriceHistoryPeriod]

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
}

// MARK: PriceChartDataOperationFactoryProtocol

extension PriceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: [PriceHistoryItem]]> {
        let allPeriods = availablePeriods

        let wrappers = allPeriods.map {
            createFetchHistoryWrapper(
                for: tokenId,
                currency: currency,
                period: $0
            )
        }

        let mapOperation = ClosureOperation<[PriceHistoryPeriod: [PriceHistoryItem]]> {
            var result: [PriceHistoryPeriod: [PriceHistoryItem]] = [:]

            return try zip(allPeriods, wrappers).reduce(into: result) { acc, pair in
                acc[pair.0] = try pair.1.targetOperation.extractNoCancellableResultData()
            }
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrappers.flatMap(\.allOperations)
        )
    }
}
