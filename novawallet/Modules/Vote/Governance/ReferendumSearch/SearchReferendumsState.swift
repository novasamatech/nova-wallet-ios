struct SearchReferendumsState {
    let referendums: [ReferendumLocal]?
    let referendumsMetadata: ReferendumMetadataMapping?
    let voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let offchainVoting: GovernanceOffchainVotesLocal?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
    let chain: ChainModel?
}
