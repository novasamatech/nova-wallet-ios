import Foundation
import BigInt
import RobinHood

enum Multistaking {
    struct OffchainFilter: Hashable {
        let chainAsset: ChainAsset
        let stakingTypes: Set<StakingType>
        let accountId: AccountId
    }

    struct OffchainRequest {
        let filters: Set<OffchainFilter>
    }

    struct OffchainActiveStaking: Hashable {
        let totalRewards: BigUInt
    }

    enum OffchainStakingState: Hashable {
        case active(OffchainActiveStaking)
        case inactive
    }

    struct OffchainStaking: Hashable {
        let chainId: ChainModel.Id
        let stakingType: StakingType
        let maxApy: Decimal
        let state: OffchainStakingState
    }

    typealias OffchainResponse = Set<OffchainStaking>
}
