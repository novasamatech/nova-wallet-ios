import Foundation
import Operation_iOS

protocol ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating?
}
