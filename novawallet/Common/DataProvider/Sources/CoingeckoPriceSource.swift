import Foundation
import RobinHood

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    let priceId: AssetModel.PriceId?
    let currency: Currency

    init(
        priceId: AssetModel.PriceId,
        currency: Currency
    ) {
        self.priceId = priceId
        self.currency = currency
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(for: [priceId], currency: currency)

            let targetOperation: BaseOperation<PriceData?> = ClosureOperation {
                try priceOperation.extractNoCancellableResultData().first
            }

            targetOperation.addDependency(priceOperation)

            return CompoundOperationWrapper(
                targetOperation: targetOperation,
                dependencies: [priceOperation]
            )
        } else {
            return CompoundOperationWrapper.createWithResult(nil)
        }
    }
}
