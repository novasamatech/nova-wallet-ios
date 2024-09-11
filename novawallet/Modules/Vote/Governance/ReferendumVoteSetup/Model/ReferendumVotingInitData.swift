import Foundation

struct ReferendumVotingInitData {
    let votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let referendum: ReferendumLocal?
    let lockDiff: GovernanceLockStateDiff?
    let presetVotingPower: VotingPowerLocal?

    init(
        votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?,
        blockNumber: BlockNumber?,
        blockTime: BlockTime?,
        referendum: ReferendumLocal?,
        lockDiff: GovernanceLockStateDiff?,
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
