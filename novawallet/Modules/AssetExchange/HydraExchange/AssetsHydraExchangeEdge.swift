import Foundation
import Operation_iOS

class AssetsHydraExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId

    init(origin: ChainAssetId, destination: ChainAssetId) {
        self.origin = origin
        self.destination = destination
    }
}

extension AssetsHydraExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

    func quote(
        amount _: Balance,
        direction _: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }
}
