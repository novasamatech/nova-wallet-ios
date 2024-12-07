import Foundation
import Operation_iOS

final class HydraExchangeOperationPrototype: AssetExchangeBaseOperationPrototype {
    let host: HydraExchangeHostProtocol

    init(assetIn: ChainAsset, assetOut: ChainAsset, host: HydraExchangeHostProtocol) {
        self.host = host

        super.init(assetIn: assetIn, assetOut: assetOut)
    }
}

extension HydraExchangeOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    var estimatedCostInUsdt: Decimal {
        // TODO: Define cost
        0
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        host.executionTimeEstimator.totalTimeWrapper(for: [host.chain.chainId])
    }
}
