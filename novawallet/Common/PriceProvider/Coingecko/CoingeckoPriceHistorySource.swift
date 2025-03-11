import Foundation
import Operation_iOS

final class CoingeckoPriceHistoryProviderSource {
    let operationFactory: CoingeckoOperationFactoryProtocol
    let currency: Currency
    let period: PriceHistoryPeriod
    let priceId: AssetModel.PriceId
    let logger: LoggerProtocol

    init(
        priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod,
        operationFactory: CoingeckoOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.priceId = priceId
        self.currency = currency
        self.period = period
        self.operationFactory = operationFactory
        self.logger = logger
    }

    private func logFetchResult(for result: Result<Model, Error>?) {
        switch result {
        case .success:
            logger.debug("Price history fetched for \(priceId)")
        case let .failure(error):
            logger.error("Price history fetch failed \(error)")
        case nil:
            logger.error("No result")
        }
    }
}

extension CoingeckoPriceHistoryProviderSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceHistory

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let historyOperation = operationFactory.fetchPriceHistory(
            for: priceId,
            currency: currency,
            period: period
        )

        let mapOperation = ClosureOperation<Model?> { [weak self] in
            self?.logFetchResult(for: historyOperation.result)
            return try historyOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(historyOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [historyOperation])
    }
}
