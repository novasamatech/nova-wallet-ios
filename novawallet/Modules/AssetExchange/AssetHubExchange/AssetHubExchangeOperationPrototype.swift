import Foundation
import Operation_iOS

final class AssetHubExchangeOperationPrototype: AssetExchangeBaseOperationPrototype {
    let host: AssetHubExchangeHostProtocol

    init(assetIn: ChainAsset, assetOut: ChainAsset, host: AssetHubExchangeHostProtocol) {
        self.host = host

        super.init(assetIn: assetIn, assetOut: assetOut)
    }
}

extension AssetHubExchangeOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        host.executionTimeEstimator.totalTimeWrapper(for: [host.chain.chainId])
    }
}
