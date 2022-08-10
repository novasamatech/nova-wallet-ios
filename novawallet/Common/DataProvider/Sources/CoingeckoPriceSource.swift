import Foundation
import RobinHood

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    let priceId: AssetModel.PriceId?
    let currencyId: String

    init(
        priceId: AssetModel.PriceId,
        currencyId: String
    ) {
        self.priceId = priceId
        self.currencyId = currencyId
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(for: [priceId], currency: currencyId)

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
