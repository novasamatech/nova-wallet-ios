import Foundation
import BigInt

struct TransactionTrackingKey: Hashable {
    let chainId: ChainModel.Id
    let transactionHash: String

    init(chainId: ChainModel.Id, transactionHash: String) {
        self.chainId = chainId
        self.transactionHash = transactionHash.lowercased()
    }
}

extension TransactionTrackingKey: CustomStringConvertible {
    var description: String {
        "\(chainId)/\(transactionHash)"
    }
}

enum TransactionTrackingEvidence {
    case evm(EvmTrackingEvidence)
}

struct EvmTrackingEvidence {
    let sender: AccountId
    let nonce: BigUInt?
}

enum TransactionTrackingMode {
    case fresh
    case recovered(rowAge: TimeInterval)

    var isRecovered: Bool {
        switch self {
        case .fresh:
            false
        case .recovered:
            true
        }
    }
}

struct TransactionTrackingRequest {
    let key: TransactionTrackingKey
    let evidence: TransactionTrackingEvidence
    let mode: TransactionTrackingMode
}

struct TransactionInclusion {
    let blockHash: String
    let blockNumber: UInt64?
    let actualFee: BigUInt?
}

enum TransactionTrackingFailureReason {
    case evmReverted
}

enum TransactionDropReason {
    case nonceConsumed
}

enum TransactionTrackingOutcome {
    case included(TransactionInclusion)
    case includedFailed(TransactionInclusion, TransactionTrackingFailureReason)
    case dropped(TransactionDropReason)
}

enum TransactionWatchResult {
    case decided(TransactionTrackingOutcome)
    case undecided
}

enum TransactionTrackingResult {
    case resolved(TransactionTrackingOutcome)
    case stillPending
}

struct TransactionTrackingHandle: TransactionTrackingHandleProtocol {
    let key: TransactionTrackingKey
}
