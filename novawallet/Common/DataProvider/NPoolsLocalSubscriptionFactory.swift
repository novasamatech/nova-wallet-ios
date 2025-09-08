import Foundation
import Operation_iOS
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

    func getDelegatedStakingDelegatorProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedDelegatedStakingDelegator>

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

    func getClaimableRewards(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<String>

    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>
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

    func getDelegatedStakingDelegatorProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedDelegatedStakingDelegator> {
        try getNoFallbackAccountProvider(
            for: DelegatedStakingPallet.delegatorsPath,
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

    func getClaimableRewards(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<String> {
        clearIfNeeded()

        let identifier = "poolPending" + chainId + accountId.toHexString()

        if let provider = getProvider(for: identifier) as? SingleValueProvider<String> {
            return AnySingleValueProvider(provider)
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let source = NPoolsPendingRewardDataSource(
            accountId: accountId,
            connection: connection,
            runtimeService: runtimeService
        )

        let anySource = AnySingleValueProviderSource<String>(source)

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: anySource,
            repository: AnyDataProviderRepository(repository)
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }

    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let timeIdentifier = [
            startTimestamp.map { "\($0)" } ?? "nil",
            endTimestamp.map { "\($0)" } ?? "nil"
        ].joined(separator: "-")

        let identifier = ("poolReward" + api.map(\.url.absoluteString).joined(with: .dash))
            + address
            + timeIdentifier

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let operationFactory = SubqueryRewardAggregatingWrapperFactory(
            factories: api.map { SubqueryRewardOperationFactory(url: $0.url) }
        )

        let source = SubqueryTotalRewardSource(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            assetPrecision: assetPrecision,
            operationFactory: operationFactory,
            stakingType: .pools
        )

        let anySource = AnySingleValueProviderSource<TotalRewardItem>(source)

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: anySource,
            repository: AnyDataProviderRepository(repository)
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }
}
