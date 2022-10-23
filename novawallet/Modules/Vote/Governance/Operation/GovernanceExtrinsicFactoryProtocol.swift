import Foundation
import SubstrateSdk

protocol GovernanceExtrinsicFactoryProtocol {
    func vote(
        _ vote: ReferendumVoteAction,
        referendum: ReferendumIdLocal,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol
}
