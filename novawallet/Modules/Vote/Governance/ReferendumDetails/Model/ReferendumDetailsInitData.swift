import Foundation

struct ReferendumDetailsInitData {
    let referendum: ReferendumLocal
    let offchainVoting: GovernanceOffchainVotesLocal.Single?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let metadata: ReferendumMetadataLocal?
    let accountVotes: ReferendumAccountVoteLocal?
    var votingAvailable: Bool

    init(
        referendum: ReferendumLocal,
        offchainVoting: GovernanceOffchainVotesLocal.Single? = nil,
        blockNumber: BlockNumber? = nil,
        blockTime: BlockTime? = nil,
        metadata: ReferendumMetadataLocal? = nil,
        accountVotes: ReferendumAccountVoteLocal? = nil,
        votingAvailable: Bool = true
    ) {
        self.referendum = referendum
        self.offchainVoting = offchainVoting
        self.blockNumber = blockNumber
        self.blockTime = blockTime
        self.metadata = metadata
        self.accountVotes = accountVotes
        self.votingAvailable = votingAvailable
    }
}
