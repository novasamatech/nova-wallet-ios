import Foundation

struct GovUnlockCalculationInfo {
    let tracks: [Referenda.TrackId: Referenda.TrackInfo]
    let undecidingTimeout: Moment
    let voteLockingPeriod: Moment
}

protocol GovernanceUnlockCalculatorProtocol {
    func estimateVoteLockingPeriod(
        for referendumInfo: ReferendumInfo,
        accountVote: ReferendumAccountVoteLocal,
        additionalInfo: GovUnlockCalculationInfo
    ) throws -> BlockNumber?

    func createUnlocksSchedule(
        for tracksVoting: ReferendumTracksVotingDistribution,
        referendums: [ReferendumIdLocal: ReferendumInfo],
        additionalInfo: GovUnlockCalculationInfo
    ) -> GovernanceUnlockSchedule
}
