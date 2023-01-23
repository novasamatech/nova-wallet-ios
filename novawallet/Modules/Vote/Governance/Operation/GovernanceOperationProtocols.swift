import Foundation
import SubstrateSdk
import RobinHood

protocol ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]>

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

    func buildUnlockScheduleWrapper(
        for tracksVoting: ReferendumTracksVotingDistribution,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data?
    ) -> CompoundOperationWrapper<GovernanceUnlockSchedule>
}

protocol GovernanceDelegateStatsFactoryProtocol {
    func fetchStatsWrapper(for activityStartBlock: BlockNumber) -> CompoundOperationWrapper<[GovernanceDelegateStats]>
}

protocol GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListWrapper(
        for activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]>
}

protocol GovernanceDelegateMetadataFactoryProtocol {
    func fetchMetadataOperation(for chain: ChainModel) -> BaseOperation<[GovernanceDelegateMetadataRemote]>
}
