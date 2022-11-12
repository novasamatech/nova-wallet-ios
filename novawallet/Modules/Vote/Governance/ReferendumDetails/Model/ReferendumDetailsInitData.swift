import Foundation

struct ReferendumDetailsInitData {
    let referendum: ReferendumLocal
    let votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let metadata: ReferendumMetadataLocal?

    var accountVotes: ReferendumAccountVoteLocal? {
        votesResult?.value?.votes.votes[referendum.index]
    }
}
