import Foundation
@testable import novawallet
import Operation_iOS

final class MockAssetsExchangePathCostEstimator {}

extension MockAssetsExchangePathCostEstimator: AssetsExchangePathCostEstimating {
    func costEstimationWrapper(
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<AssetsExchangePathCost> {
        CompoundOperationWrapper.createWithResult(.zero)
    }
}
