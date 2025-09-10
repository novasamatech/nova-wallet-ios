import SubstrateSdk

enum TimepointThreshold: Equatable {
    case block(blockNumber: BlockNumber, blockTime: BlockTime)
    case timestamp(Int64)

    func backIn(days: Int) -> Self {
        switch self {
        case let .timestamp(timestamp):
            .timestamp(timestamp - Int64(Double.secondsInDay) * Int64(days))
        case let .block(blockNumber, blockTime):
            .block(
                blockNumber: blockNumber.blockBackInDays(
                    days,
                    blockTime: blockTime
                ) ?? blockNumber,
                blockTime: blockTime
            )
        }
    }
}
