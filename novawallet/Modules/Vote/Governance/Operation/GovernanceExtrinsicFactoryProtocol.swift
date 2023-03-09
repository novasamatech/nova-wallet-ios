import Foundation
import SubstrateSdk

protocol GovernanceExtrinsicFactoryProtocol {
    func vote(
        _ vote: ReferendumVoteAction,
        referendum: ReferendumIdLocal,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol

    func unlock(
        with actions: Set<GovernanceUnlockSchedule.Action>,
        accountId: AccountId,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol

    func delegationUpdate(
        with actions: [GovernanceDelegatorAction],
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting
}
