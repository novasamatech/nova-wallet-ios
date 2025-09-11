import SubstrateSdk

struct TimepointThreshold: Equatable {
    private var additionalValue: Int64?

    let type: TimepointThresholdType

    var value: Int64 {
        switch type {
        case .timestamp:
            Int64(Date().timeIntervalSince1970) + Int64(Double.secondsInDay) * (additionalValue ?? 0)
        case let .block(blockNumber, blockTime):
            Int64(blockNumber)
        }
    }

    init(type: TimepointThresholdType) {
        self.type = type
    }

    private init(
        type: TimepointThresholdType,
        additionalValue: Int64
    ) {
        self.type = type
        self.additionalValue = additionalValue
    }

    func backIn(seconds: TimeInterval) -> Self {
        let updatedType: TimepointThresholdType = switch type {
        case .timestamp:
            .timestamp
        case let .block(blockNumber, blockTime):
            .block(
                blockNumber: blockNumber.blockBackIn(
                    seconds,
                    blockTime: blockTime
                ) ?? blockNumber,
                blockTime: blockTime
            )
        }

        return .init(
            type: updatedType,
            additionalValue: -Int64(seconds)
        )
    }
}

enum TimepointThresholdType: Equatable {
    case block(blockNumber: BlockNumber, blockTime: BlockTime)
    case timestamp
}
