import Foundation

enum LedgerError: Error {
    case deviceNotFound
    case deviceDisconnected
    case response(error: LedgerResponseError)
    case unexpectedData(_ details: String)
    case internalTransport(error: Error)
}

struct LedgerResponseError {
    let code: LedgerResponseCode
    let reasonData: Data

    var reason: String? {
        String(data: reasonData, encoding: .utf8)
    }
}

extension LedgerResponseError {
    func isValidAppNotOpen() -> Bool {
        switch code {
        case .appNotOpen, .wrongAppOpen:
            return true
        default:
            return false
        }
    }
}
