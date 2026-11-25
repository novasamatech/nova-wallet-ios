import Foundation
import BigInt

struct EvmTransactionMonitorTiming {
    let pollInterval: TimeInterval
    let waitBudget: TimeInterval
    let droppedWindow: TimeInterval
    let minHeadCheckSpacing: TimeInterval
    let slowPollInterval: TimeInterval
    let idlePollInterval: TimeInterval

    func interval(forAge age: TimeInterval) -> TimeInterval {
        if age < waitBudget {
            pollInterval
        } else if age < Constants.idleAge {
            slowPollInterval
        } else {
            idlePollInterval
        }
    }
}

extension EvmTransactionMonitorTiming {
    init(chain: ChainModel) {
        let blockTime = chain.defaultBlockTimeMillis.map { TimeInterval($0) / 1000 } ?? Constants.fallbackBlockTime
        let agedPollBase = min(max(blockTime, Constants.minPollInterval), Constants.maxSlowBaseInterval)

        self.init(
            pollInterval: min(max(blockTime, Constants.minPollInterval), Constants.maxPollInterval),
            waitBudget: max(Constants.minWaitBudget, Constants.waitBudgetBlocks * blockTime),
            droppedWindow: max(Constants.minDroppedWindow, Constants.droppedWindowBlocks * blockTime),
            minHeadCheckSpacing: Constants.minHeadCheckSpacing,
            slowPollInterval: min(Constants.maxAgedPollInterval, agedPollBase * Constants.slowPollFactor),
            idlePollInterval: min(Constants.maxAgedPollInterval, agedPollBase * Constants.idlePollFactor)
        )
    }

    private enum Constants {
        static let fallbackBlockTime: TimeInterval = 12
        static let minPollInterval: TimeInterval = 1
        static let maxPollInterval: TimeInterval = 4
        static let minWaitBudget: TimeInterval = 60
        static let waitBudgetBlocks: TimeInterval = 10
        static let minDroppedWindow: TimeInterval = 30
        static let droppedWindowBlocks: TimeInterval = 3
        static let minHeadCheckSpacing: TimeInterval = 2
        static let maxSlowBaseInterval: TimeInterval = 12
        static let slowPollFactor: TimeInterval = 3
        static let idlePollFactor: TimeInterval = 10
        static let maxAgedPollInterval: TimeInterval = 120
        static let idleAge: TimeInterval = 3600
    }
}

struct EvmTransactionMonitorState {
    enum Check {
        case receipt(EthereumTransactionReceipt)
        case noReceipt(latestNonce: BigUInt)
        case unavailable
    }

    enum Decision: Equatable {
        case wait
        case verifyDropped
        case success(EthereumTransactionReceipt)
        case failure(EthereumTransactionReceipt)
        case dropped
        case stillPending
    }

    let nonce: BigUInt?
    let timing: EvmTransactionMonitorTiming
    let startedAt: Date
    let deadline: TimeInterval?

    private(set) var consumedChecks: Int = 0
    private(set) var consumedSince: Date?

    init(nonce: BigUInt?, timing: EvmTransactionMonitorTiming, startedAt: Date, deadline: TimeInterval?) {
        self.nonce = nonce
        self.timing = timing
        self.startedAt = startedAt
        self.deadline = deadline
    }

    mutating func decide(on check: Check, at date: Date) -> Decision {
        if case let .receipt(receipt) = check {
            return Self.decide(on: receipt)
        }

        guard case let .noReceipt(latestNonce) = check else {
            return .wait
        }

        if let nonce, latestNonce > nonce {
            return decideConsumedNonce(at: date)
        }

        if let deadline, date.timeIntervalSince(startedAt) >= deadline {
            return .stillPending
        }

        consumedChecks = 0
        consumedSince = nil

        return .wait
    }

    func decideVerification(_ result: Result<EthereumTransactionReceipt?, Error>) -> Decision {
        switch result {
        case let .success(receipt?):
            return Self.decide(on: receipt)
        case .success(nil):
            return .dropped
        case .failure:
            return .wait
        }
    }
}

private extension EvmTransactionMonitorState {
    enum Constants {
        static let minConsumedChecks = 4
    }

    mutating func decideConsumedNonce(at date: Date) -> Decision {
        consumedChecks += 1

        let streakStart = consumedSince ?? date
        consumedSince = streakStart

        let isDroppedCandidate = consumedChecks >= Constants.minConsumedChecks &&
            date.timeIntervalSince(streakStart) >= timing.droppedWindow

        return isDroppedCandidate ? .verifyDropped : .wait
    }

    static func decide(on receipt: EthereumTransactionReceipt) -> Decision {
        if receipt.isSuccess ?? true {
            return .success(receipt)
        } else {
            return .failure(receipt)
        }
    }
}
