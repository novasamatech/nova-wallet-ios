import Foundation
import BigInt

struct EvmTransactionMonitorTiming {
    let pollInterval: TimeInterval
    let waitBudget: TimeInterval
    let droppedWindow: TimeInterval
    let minHeadCheckSpacing: TimeInterval
}

extension EvmTransactionMonitorTiming {
    init(chain: ChainModel) {
        let blockTime = chain.defaultBlockTimeMillis.map { TimeInterval($0) / 1000 } ?? Constants.fallbackBlockTime

        self.init(
            pollInterval: min(max(blockTime, Constants.minPollInterval), Constants.maxPollInterval),
            waitBudget: max(Constants.minWaitBudget, Constants.waitBudgetBlocks * blockTime),
            droppedWindow: max(Constants.minDroppedWindow, Constants.droppedWindowBlocks * blockTime),
            minHeadCheckSpacing: Constants.minHeadCheckSpacing
        )
    }

    private enum Constants {
        static let fallbackBlockTime: TimeInterval = 12
        static let minPollInterval: TimeInterval = 1
        static let maxPollInterval: TimeInterval = 4
        static let minWaitBudget: TimeInterval = 60
        static let waitBudgetBlocks: TimeInterval = 10
        static let minDroppedWindow: TimeInterval = 12
        static let droppedWindowBlocks: TimeInterval = 3
        static let minHeadCheckSpacing: TimeInterval = 2
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
        case success(transactionHash: String, blockHash: String)
        case failure(transactionHash: String)
        case dropped
        case stillPending
    }

    let nonce: BigUInt
    let timing: EvmTransactionMonitorTiming
    let startedAt: Date

    private(set) var consumedChecks: Int = 0
    private(set) var consumedSince: Date?

    init(nonce: BigUInt, timing: EvmTransactionMonitorTiming, startedAt: Date) {
        self.nonce = nonce
        self.timing = timing
        self.startedAt = startedAt
    }

    mutating func decide(on check: Check, at date: Date) -> Decision {
        if case let .receipt(receipt) = check {
            return Self.decide(on: receipt)
        }

        guard date.timeIntervalSince(startedAt) < timing.waitBudget else {
            return .stillPending
        }

        guard case let .noReceipt(latestNonce) = check else {
            return .wait
        }

        guard latestNonce > nonce else {
            consumedChecks = 0
            consumedSince = nil
            return .wait
        }

        consumedChecks += 1

        let streakStart = consumedSince ?? date
        consumedSince = streakStart

        let isDroppedCandidate = consumedChecks >= Constants.minConsumedChecks &&
            date.timeIntervalSince(streakStart) >= timing.droppedWindow

        return isDroppedCandidate ? .verifyDropped : .wait
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

    static func decide(on receipt: EthereumTransactionReceipt) -> Decision {
        if receipt.isSuccess ?? true {
            return .success(transactionHash: receipt.transactionHash, blockHash: receipt.blockHash)
        } else {
            return .failure(transactionHash: receipt.transactionHash)
        }
    }
}
