import Foundation
import SubstrateSdk
import RobinHood

protocol ParaStkYieldBoostSupportProtocol {
    func checkSupport(for chainAsset: ChainAsset) -> Bool
}

final class ParaStkYieldBoostSupport: ParaStkYieldBoostSupportProtocol {
    func checkSupport(for chainAsset: ChainAsset) -> Bool {
        StakingType(rawType: chainAsset.asset.staking) == .turing
    }
}
