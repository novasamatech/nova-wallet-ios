import Foundation
import RobinHood

final class CoingeckoPriceListSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    let priceIds: [AssetModel.PriceId]
    let currencyId: String

    init(
        priceIds: [AssetModel.PriceId],
        currencyId: String
    ) {
        self.priceIds = priceIds
        self.currencyId = currencyId
    }

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let fethOperation = CoingeckoOperationFactory().fetchPriceOperation(
            for: priceIds,
            currency: currencyId
        )

        let mappingOperation = ClosureOperation<Model?> {
            try fethOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(fethOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fethOperation])
    }
}
