import Foundation
import BigInt

protocol NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleBondedPool(
        result: Result<NominationPools.BondedPool?, Error>,
        poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    )

    func handleDelegatedStaking(
        result: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handlePoolMetadata(
        result: Result<Data?, Error>,
        poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    )

    func handleRewardPool(
        result: Result<NominationPools.RewardPool?, Error>,
        poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    )

    func handleSubPools(
        result: Result<NominationPools.SubPools?, Error>,
        poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    )

    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId: ChainModel.Id)

    func handleLastPoolId(result: Result<NominationPools.PoolId?, Error>, chainId: ChainModel.Id)

    func handleMaxPoolMembers(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id)

    func handleCounterForPoolMembers(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id)

    func handleMaxPoolMembersPerPool(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id)

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        accountId: AccountId
    )

    func handlePoolTotalReward(
        result _: Result<TotalRewardItem?, Error>,
        for _: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api _: Set<LocalChainExternalApi>
    )
}

extension NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result _: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleBondedPool(
        result _: Result<NominationPools.BondedPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {}

    func handleDelegatedStaking(
        result _: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handlePoolMetadata(
        result _: Result<Data?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {}

    func handleRewardPool(
        result _: Result<NominationPools.RewardPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {}

    func handleSubPools(
        result _: Result<NominationPools.SubPools?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {}

    func handleMinJoinBond(result _: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {}

    func handleLastPoolId(result _: Result<NominationPools.PoolId?, Error>, chainId _: ChainModel.Id) {}

    func handleMaxPoolMembers(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleCounterForPoolMembers(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleMaxPoolMembersPerPool(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleClaimableRewards(
        result _: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId _: NominationPools.PoolId,
        accountId _: AccountId
    ) {}

    func handlePoolTotalReward(
        result _: Result<TotalRewardItem?, Error>,
        for _: AccountAddress,
        startTimestamp _: Int64?,
        endTimestamp _: Int64?,
        api _: Set<LocalChainExternalApi>
    ) {}
}
