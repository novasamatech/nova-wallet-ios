import Foundation

enum EvmTransactionMonitorError: Error {
    case dropped(transactionHash: String)
    case stillPending(transactionHash: String)

    var mayStillLand: Bool {
        switch self {
        case .dropped:
            false
        case .stillPending:
            true
        }
    }
}
