import Foundation

struct ReferendumDetailsInitData {
    let referendum: ReferendumLocal
    let offchainVoting: GovernanceOffchainVotesLocal.Single?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let metadata: ReferendumMetadataLocal?
    let accountVotes: ReferendumAccountVoteLocal?
    var votingAvailable: Bool = true
}
