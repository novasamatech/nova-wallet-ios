import SubstrateSdk

enum RecentVotesDateThreshold {
    case blockNumber(BlockNumber)
    case timestamp(Int64)
}
