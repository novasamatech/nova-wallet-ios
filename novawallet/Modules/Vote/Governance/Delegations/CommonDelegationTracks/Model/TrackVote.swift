import BigInt

struct TrackVote {
    let track: GovernanceTrackInfoLocal
    let vote: Vote?

    struct Vote {
        let balance: BigUInt
        let conviction: ConvictionVoting.Conviction
    }
}
