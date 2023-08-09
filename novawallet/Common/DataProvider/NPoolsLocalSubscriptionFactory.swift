import Foundation
import RobinHood
import SubstrateSdk

protocol NPoolsLocalSubscriptionFactoryProtocol {
    func getMinJoinBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getLastPoolIdProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPoolId>

    func getPoolMemberProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPoolMember>

    func getBondedPoolProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBondedPool>

    func getMetadataProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBytes>

    func getRewardPoolProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedRewardPool>

    func getSubPoolsProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedSubPools>

    func getMaxPoolMembers(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>

    func getCounterForPoolMembers(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>

    func getMaxMembersPerPool(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>
}

final class NPoolsLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory {}

extension NPoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol {
    func getMinJoinBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getNoFallbackPathProvider(for: NominationPools.minJoinBondPath, chainId: chainId)
    }

    func getLastPoolIdProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPoolId> {
        try getNoFallbackPathProvider(for: NominationPools.lastPoolIdPath, chainId: chainId)
    }

    func getPoolMemberProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPoolMember> {
        try getNoFallbackAccountProvider(
            for: NominationPools.poolMembersPath,
            accountId: accountId,
            chainId: chainId
        )
    }

    func getBondedPoolProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBondedPool> {
        try getNoFallbackScalingElementProvider(
            for: NominationPools.bondedPoolPath,
            encodableElement: poolId,
            chainId: chainId
        )
    }

    func getMetadataProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBytes> {
        try getNoFallbackScalingElementProvider(
            for: NominationPools.metadataPath,
            encodableElement: poolId,
            chainId: chainId
        )
    }

    func getRewardPoolProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedRewardPool> {
        try getNoFallbackScalingElementProvider(
            for: NominationPools.rewardPoolsPath,
            encodableElement: poolId,
            chainId: chainId
        )
    }

    func getSubPoolsProvider(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedSubPools> {
        try getNoFallbackScalingElementProvider(
            for: NominationPools.subPoolsPath,
            encodableElement: poolId,
            chainId: chainId
        )
    }

    func getMaxPoolMembers(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = NominationPools.maxPoolMembers
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }

    func getCounterForPoolMembers(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = NominationPools.counterForPoolMembers
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }

    func getMaxMembersPerPool(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = NominationPools.maxMembersPerPool
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }
}
