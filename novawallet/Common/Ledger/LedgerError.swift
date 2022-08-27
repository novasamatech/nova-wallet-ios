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

    func reason() -> String? {
        // reason string has 4 bytes length on suffix
        let lengthSize = 4

        guard reasonData.count >= lengthSize else {
            return nil
        }

        let length = UInt32(bigEndianData: reasonData.suffix(lengthSize))

        let remainedData = reasonData.dropLast(lengthSize)

        guard remainedData.count >= length else {
            return nil
        }

        return String(data: remainedData.suffix(Int(length)), encoding: .utf8)
    }
}
