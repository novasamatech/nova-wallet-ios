import Foundation

enum TransferAnalyticsFlow {
    case send
    case offRamp
    case cardTopUp
    case crossChainTopUp
}

extension TransferAnalyticsFlow {
    var tracksSendFunnel: Bool {
        switch self {
        case .send:
            true
        case .offRamp, .cardTopUp, .crossChainTopUp:
            false
        }
    }
}
