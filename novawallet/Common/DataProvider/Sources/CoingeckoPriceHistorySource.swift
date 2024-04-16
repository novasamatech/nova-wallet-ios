import Foundation
import RobinHood

final class CoingeckoPriceHistoryProviderSource {
    static let maxAllowedRange = 365.secondsFromDays

    let operationFactory: CoingeckoOperationFactoryProtocol
    let currency: Currency
    let priceId: AssetModel.PriceId
    let logger: LoggerProtocol

    init(
        priceId: AssetModel.PriceId,
        currency: Currency,
        operationFactory: CoingeckoOperationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.priceId = priceId
        self.currency = currency
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
        let toTimeInterval = Date().timeIntervalSince1970
        let fromTimeInterval = max(toTimeInterval - Self.maxAllowedRange, 0)

        let historyOperation = operationFactory.fetchPriceHistory(
            for: priceId,
            currency: currency,
            startDate: Date(timeIntervalSince1970: fromTimeInterval),
            endDate: Date(timeIntervalSince1970: toTimeInterval)
        )

        let mapOperation = ClosureOperation<Model?> { [weak self] in
            self?.logFetchResult(for: historyOperation.result)
            return try historyOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(historyOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [historyOperation])
    }
}
