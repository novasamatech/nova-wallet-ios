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
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting

    func delegationUpdate(
        with actions: [GovernanceDelegatorAction],
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting
}
