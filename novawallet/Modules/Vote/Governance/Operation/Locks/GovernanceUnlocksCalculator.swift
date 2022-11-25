import Foundation

struct GovUnlockCalculationInfo {
    let decisionPeriods: [Referenda.TrackId: Moment]
    let undecidingTimeout: Moment
    let voteLockingPeriod: Moment
}

protocol GovUnlockReferendumProtocol {
    func estimateVoteLockingPeriod(
        for accountVote: ReferendumAccountVoteLocal,
        additionalInfo: GovUnlockCalculationInfo
    ) throws -> BlockNumber?
}

protocol GovernanceUnlockCalculatorProtocol {
    func createUnlocksSchedule(
        for tracksVoting: ReferendumTracksVotingDistribution,
        referendums: [ReferendumIdLocal: GovUnlockReferendumProtocol],
        additionalInfo: GovUnlockCalculationInfo
    ) -> GovernanceUnlockSchedule
}
