import Foundation
import SubstrateSdk
import Operation_iOS

protocol ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]>

    func fetchAllTracks(
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[GovernanceTrackInfoLocal]>

    func fetchAccountVotesWrapper(
        for accountId: AccountId,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<ReferendumAccountVotingDistribution>

    func fetchVotersWrapper(
        for referendumIndex: ReferendumIdLocal,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]>

    func fetchReferendumsWrapper(
        for referendumIds: Set<ReferendumIdLocal>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]>
}

protocol ReferendumActionOperationFactoryProtocol {
    func fetchActionWrapper(
        for referendum: ReferendumLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        spendAmountExtractor: GovSpendingExtracting
    ) -> CompoundOperationWrapper<ReferendumActionLocal>
}

protocol GovernanceLockStateFactoryProtocol {
    func calculateLockStateDiff(
        for trackVotes: ReferendumTracksVotingDistribution,
        newVotes: [ReferendumNewVote]?,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceLockStateDiff>

    func calculateDelegateStateDiff(
        for trackVotes: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<GovernanceDelegateStateDiff>

    func buildUnlockScheduleWrapper(
        for tracksVoting: ReferendumTracksVotingDistribution,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceUnlockSchedule>
}

protocol GovernanceDelegateStatsFactoryProtocol {
    func fetchStatsWrapper(for threshold: TimepointThreshold) -> CompoundOperationWrapper<[GovernanceDelegateStats]>

    func fetchStatsByIdsWrapper(
        from delegateIds: Set<AccountAddress>,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]>

    func fetchDetailsWrapper(
        for delegate: AccountAddress,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<GovernanceDelegateDetails?>
}

protocol GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListWrapper(
        for threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]>

    func fetchDelegateListByIdsWrapper(
        from delegateIds: Set<AccountId>,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]>
}

protocol GovernanceDelegateMetadataFactoryProtocol {
    func fetchMetadataOperation(for chain: ChainModel) -> BaseOperation<[GovernanceDelegateMetadataRemote]>
}
