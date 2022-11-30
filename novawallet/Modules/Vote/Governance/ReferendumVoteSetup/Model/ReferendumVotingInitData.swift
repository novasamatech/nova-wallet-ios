import Foundation

struct ReferendumVotingInitData {
    let votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let referendum: ReferendumLocal?
    let lockDiff: GovernanceLockStateDiff?
}
