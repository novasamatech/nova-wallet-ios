import Foundation

enum TransferAnalyticsFlow {
    case send
    case offRamp
    case crossChainTopUp
}

extension TransferAnalyticsFlow {
    var tracksSendFunnel: Bool {
        switch self {
        case .send:
            true
        case .offRamp, .crossChainTopUp:
            false
        }
    }
}
