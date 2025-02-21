import Foundation
import Operation_iOS

extension ParachainStaking {
    typealias DecodedRoundInfo = ChainStorageDecodedItem<ParachainStaking.RoundInfo>
    typealias DecodedInflationConfig = ChainStorageDecodedItem<ParachainStaking.InflationConfig>
    typealias DecodedParachainBondConfig = ChainStorageDecodedItem<
        ParachainStaking.ParachainBondConfig
    >
    typealias DecodedInflationDistributionInfo = ChainStorageDecodedItem<
        ParachainStaking.InflationDistributionInfo
    >
    typealias DecodedDelegator = ChainStorageDecodedItem<ParachainStaking.Delegator>
    typealias MappedScheduledRequest = ChainStorageDecodedItem<[ParachainStaking.DelegatorScheduledRequest]>
    typealias DecodedScheduledRequests = ChainStorageDecodedItem<
        [ParachainStaking.ScheduledRequest]
    >
    typealias DecodedCandidateMetadata = ChainStorageDecodedItem<ParachainStaking.CandidateMetadata>
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

    func getInflationDistributionInfoProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationDistributionInfo>

    func getDelegatorStateProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedDelegator>

    func getScheduledRequestsProvider(
        for chainId: ChainModel.Id,
        delegatorId: AccountId
    ) throws -> StreamableProvider<ParachainStaking.MappedScheduledRequest>

    func getCandidateMetadataProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedCandidateMetadata>
}

final class ParachainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    ParachainStakingLocalSubscriptionFactoryProtocol {
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

    func getInflationDistributionInfoProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationDistributionInfo> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.inflationDistributionInfoPath)
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
        delegatorId: AccountId
    ) throws -> StreamableProvider<ParachainStaking.MappedScheduledRequest> {
        let localKey = try LocalStorageKeyFactory().createRestorableRecurrentKey(
            from: ParachainStaking.delegationRequestsPath,
            chainId: chainId,
            items: [delegatorId]
        )

        if let provider = getProvider(for: localKey) as? StreamableProvider<ParachainStaking.MappedScheduledRequest> {
            return provider
        }

        let source = EmptyStreamableSource<ParachainStaking.MappedScheduledRequest>()
        let mapper = ParaStkScheduledRequestsMapper()
        let filter = NSPredicate.filterStorageItemsBy(identifier: localKey)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { $0.identifier == localKey },
            processingQueue: nil
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Unexpected error \(error)")
            }
        }

        let streamableProvider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(streamableProvider, for: localKey)

        return streamableProvider
    }

    func getCandidateMetadataProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<ParachainStaking.DecodedCandidateMetadata> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: ParachainStaking.candidateMetadataPath
        )
    }
}
