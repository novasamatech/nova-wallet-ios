import Foundation
import Operation_iOS

protocol AssetExchangeOperationPrototypeProtocol {
    var assetIn: ChainAsset { get }
    var assetOut: ChainAsset { get }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval>
}

class AssetExchangeBaseOperationPrototype {
    let assetIn: ChainAsset
    let assetOut: ChainAsset

    init(assetIn: ChainAsset, assetOut: ChainAsset) {
        self.assetIn = assetIn
        self.assetOut = assetOut
    }
}
