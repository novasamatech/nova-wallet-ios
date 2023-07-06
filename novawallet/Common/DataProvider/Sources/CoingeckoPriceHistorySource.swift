import Foundation
import RobinHood

final class CoingeckoPriceHistoryProviderSource {
    let operationFactory: CoingeckoOperationFactoryProtocol
    let currency: Currency
    let priceId: AssetModel.PriceId

    init(
        priceId: AssetModel.PriceId,
        currency: Currency,
        operationFactory: CoingeckoOperationFactoryProtocol
    ) {
        self.priceId = priceId
        self.currency = currency
        self.operationFactory = operationFactory
    }
}

extension CoingeckoPriceHistoryProviderSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceHistory

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let historyOperation = operationFactory.fetchPriceHistory(
            for: priceId,
            currency: currency,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: TimeInterval(UInt32.max))
        )

        let mapOperation = ClosureOperation<Model?> {
            try historyOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(historyOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [historyOperation])
    }
}
