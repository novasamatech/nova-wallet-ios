import Foundation
import Operation_iOS

final class CrosschainExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId

    init(origin: ChainAssetId, destination: ChainAssetId) {
        self.origin = origin
        self.destination = destination
    }
}

extension CrosschainExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { 1 }

    func quote(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithResult(amount)
    }
}
