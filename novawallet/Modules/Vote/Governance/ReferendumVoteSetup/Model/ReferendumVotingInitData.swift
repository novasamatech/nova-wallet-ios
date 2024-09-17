import Foundation

struct ReferendumVotingInitData {
    let votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let referendum: ReferendumLocal?
    let lockDiff: GovernanceLockStateDiff?
    let presetVotingPower: VotingPowerLocal?

    init(
        votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>? = nil,
        blockNumber: BlockNumber? = nil,
        blockTime: BlockTime? = nil,
        referendum: ReferendumLocal? = nil,
        lockDiff: GovernanceLockStateDiff? = nil,
        presetVotingPower: VotingPowerLocal? = nil
    ) {
        self.votesResult = votesResult
        self.blockNumber = blockNumber
        self.blockTime = blockTime
        self.referendum = referendum
        self.lockDiff = lockDiff
        self.presetVotingPower = presetVotingPower
    }
}
