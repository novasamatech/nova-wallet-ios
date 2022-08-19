import Foundation

enum LedgerError: Error {
    case deviceUnavailable
    case response(code: LedgerResponse)
    case unexpectedData(_ details: String)
}
