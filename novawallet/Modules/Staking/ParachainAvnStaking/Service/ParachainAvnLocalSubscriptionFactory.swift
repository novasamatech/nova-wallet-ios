import Foundation
import Operation_iOS

/// Local subscription factory for Energy Web X staking.
///
/// Overrides the round (era) and commission storage paths to match
/// EWX's AvN-fork naming (`Era` instead of `Round`,
/// `DefaultCollatorCommission` instead of `CollatorCommission`).
/// All other providers fall through to the base Moonbeam implementation
/// since the storage item names and types match.
final class ParachainAvnLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    ParachainStakingLocalSubscriptionFactoryProtocol {
    func getRoundProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedRoundInfo> {
        // EWX calls its round info "Era" (same shape as Moonbeam's "Round")
        try getPlainProvider(for: chainId, storagePath: ParachainAvn.eraPath)
    }

    func getCollatorCommissionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        // EWX uses "DefaultCollatorCommission" (global, not per-collator)
        try getPlainProvider(for: chainId, storagePath: ParachainAvn.defaultCollatorCommissionPath)
    }

    func getTotalIssuanceProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: StorageCodingPath.totalIssuance)
    }

    func getInflationProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationConfig> {
        // EWX does not have InflationConfig — this will return nil/empty
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
        // EWX uses "NominatorState" — same structure as Moonbeam's "DelegatorState"
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: ParachainAvn.nominatorStatePath
        )
    }

    func getScheduledRequestsProvider(
        for chainId: ChainModel.Id,
        delegatorId: AccountId
    ) throws -> StreamableProvider<ParachainStaking.MappedScheduledRequest> {
        // EWX uses "NominationScheduledRequests"
        let localKey = try LocalStorageKeyFactory().createRestorableRecurrentKey(
            from: ParachainAvn.nominationScheduledRequestsPath,
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
        // EWX and Moonbeam both call this "CandidateInfo"
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: ParachainAvn.candidateInfoPath
        )
    }
}
