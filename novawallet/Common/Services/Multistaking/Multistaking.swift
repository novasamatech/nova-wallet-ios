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

    enum OffchainStakingState: Hashable {
        case active
        case inactive
    }

    struct OffchainStaking: Hashable {
        let chainId: ChainModel.Id
        let stakingType: StakingType
        let maxApy: Decimal
        let state: OffchainStakingState
        let totalRewards: BigUInt?
    }

    typealias OffchainResponse = Set<OffchainStaking>
}
