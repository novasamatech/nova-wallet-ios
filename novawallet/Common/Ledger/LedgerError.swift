import Foundation

enum LedgerError: Error {
    case deviceUnavailable
    case response(code: LedgerResponseCode)
    case unexpectedData(_ details: String)
}
