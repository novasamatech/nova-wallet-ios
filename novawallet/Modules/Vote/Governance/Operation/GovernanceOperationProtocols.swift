import Foundation
import SubstrateSdk
import RobinHood

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
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<ReferendumActionLocal>
}

protocol GovernanceLockStateFactoryProtocol {
    func calculateLockStateDiff(
        for trackVotes: ReferendumTracksVotingDistribution,
        newVote: ReferendumNewVote?,
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
    func fetchStatsWrapper(for activityStartBlock: BlockNumber) -> CompoundOperationWrapper<[GovernanceDelegateStats]>

    func fetchStatsByIdsWrapper(
        from delegateIds: Set<AccountAddress>,
        activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]>

    func fetchDetailsWrapper(
        for delegate: AccountAddress,
        activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<GovernanceDelegateDetails?>
}

protocol GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListWrapper(
        for activityStartBlock: BlockNumber,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]>

    func fetchDelegateListByIdsWrapper(
        from delegateIds: Set<AccountId>,
        activityStartBlock: BlockNumber,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]>
}

protocol GovernanceDelegateMetadataFactoryProtocol {
    func fetchMetadataOperation(for chain: ChainModel) -> BaseOperation<[GovernanceDelegateMetadataRemote]>
}
