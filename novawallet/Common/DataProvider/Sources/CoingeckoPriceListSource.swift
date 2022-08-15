import Foundation
import RobinHood

final class CoingeckoPriceListSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    let priceIds: [AssetModel.PriceId]
    let currency: Currency

    init(
        priceIds: [AssetModel.PriceId],
        currency: Currency
    ) {
        self.priceIds = priceIds
        self.currency = currency
    }

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let fethOperation = CoingeckoOperationFactory().fetchPriceOperation(
            for: priceIds,
            currency: currency
        )

        let mappingOperation = ClosureOperation<Model?> {
            try fethOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(fethOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fethOperation])
    }
}
