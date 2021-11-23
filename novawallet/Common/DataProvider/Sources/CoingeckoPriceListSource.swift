import Foundation
import RobinHood

final class CoingeckoPriceListSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    let priceIds: [AssetModel.PriceId]

    init(priceIds: [AssetModel.PriceId]) {
        self.priceIds = priceIds
    }

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let fethOperation = CoingeckoOperationFactory().fetchPriceOperation(for: priceIds)

        let mappingOperation = ClosureOperation<Model?> {
            try fethOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(fethOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fethOperation])
    }
}
