import Foundation

enum LedgerError: Error {
    case deviceNotFound
    case deviceDisconnected
    case response(code: LedgerResponseCode)
    case unexpectedData(_ details: String)
    case internalTransport(error: Error)
}
