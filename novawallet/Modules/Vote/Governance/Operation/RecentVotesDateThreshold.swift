import SubstrateSdk

enum TimepointThreshold {
    case blockNumber(BlockNumber)
    case timestamp(Int64)
}
