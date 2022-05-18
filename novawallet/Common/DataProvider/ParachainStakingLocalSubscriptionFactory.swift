import Foundation
import RobinHood

extension ParachainStaking {
    typealias DecodedRoundInfo = ChainStorageDecodedItem<ParachainStaking.RoundInfo>
    typealias DecodedInflationConfig = ChainStorageDecodedItem<ParachainStaking.InflationConfig>
    typealias DecodedParachainBondConfig = ChainStorageDecodedItem<
        ParachainStaking.ParachainBondConfig
    >
    typealias DecodedDelegator = ChainStorageDecodedItem<ParachainStaking.Delegator>
    typealias DecodedScheduledRequests = ChainStorageDecodedItem<
        [ParachainStaking.ScheduledRequest]
    >
}

protocol ParachainStakingLocalSubscriptionFactoryProtocol {
    func getRoundProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedRoundInfo>

    func getCollatorCommissionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getTotalIssuanceProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getInflationProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationConfig>

    func getParachainBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedParachainBondConfig>

    func getDelegatorStateProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedDelegator>

    func getScheduledRequestsProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedScheduledRequests>

    func getTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>
}

final class ParachainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    ParachainStakingLocalSubscriptionFactoryProtocol {
    private func getPlainProvider<T: Equatable & Decodable>(
        for chainId: ChainModel.Id,
        storagePath: StorageCodingPath
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }

    private func getAccountProvider<T: Equatable & Decodable>(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        storagePath: StorageCodingPath
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }

    func getRoundProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedRoundInfo> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.roundPath)
    }

    func getCollatorCommissionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.collatorCommissionPath)
    }

    func getTotalIssuanceProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: StorageCodingPath.totalIssuance)
    }

    func getInflationProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationConfig> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.inflationConfigPath)
    }

    func getParachainBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedParachainBondConfig> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.parachainBondInfoPath)
    }

    func getDelegatorStateProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedDelegator> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: ParachainStaking.delegatorStatePath
        )
    }

    func getScheduledRequestsProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedScheduledRequests> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: ParachainStaking.delegationRequestsPath
        )
    }

    func getTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let identifier = ("reward" + api.url.absoluteString) + address

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let operationFactory = SubqueryRewardOperationFactory(url: api.url)

        let source = SubqueryTotalRewardSource(
            address: address,
            assetPrecision: assetPrecision,
            operationFactory: operationFactory
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
