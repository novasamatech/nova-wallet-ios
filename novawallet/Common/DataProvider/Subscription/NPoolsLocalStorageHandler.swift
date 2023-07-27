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
}
