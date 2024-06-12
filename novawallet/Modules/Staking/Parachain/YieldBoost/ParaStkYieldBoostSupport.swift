import Foundation
import SubstrateSdk
import Operation_iOS

protocol ParaStkYieldBoostSupportProtocol {
    func checkSupport(for chainAsset: ChainAsset) -> Bool
}

final class ParaStkYieldBoostSupport: ParaStkYieldBoostSupportProtocol {
    func checkSupport(for chainAsset: ChainAsset) -> Bool {
        chainAsset.asset.stakings?.contains(.turing) ?? false
    }
}
