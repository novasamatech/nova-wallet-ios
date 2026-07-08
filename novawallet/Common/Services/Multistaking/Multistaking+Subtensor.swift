import Foundation
import BigInt

extension Multistaking {
    /// On-chain stake snapshot for a single Bittensor netuid.
    ///
    /// For netuid=0 this is TAO (root alpha is 1:1 TAO). For netuid>0 this is
    /// the subnet's own alpha token.
    struct SubtensorStakingState: Equatable {
        let totalStake: BigUInt
    }

    /// Partial dashboard item persisted by SubtensorMultistakingUpdateService —
    /// one per (wallet, ChainAsset, StakingType=.subtensor) tuple.
    struct DashboardItemSubtensorPart: Equatable {
        let stakingOption: OptionWithWallet
        let state: SubtensorStakingState
    }
}
