import Foundation

protocol LedgerDecodable {
    init(ledgerData: Data) throws
}

enum LedgerResponseCode: UInt16 {
    case unknown = 1
    case badRequest = 2
    case unsupported = 3
    case ineligibleDevice = 4
    case timeoutU2f = 5
    case timeout = 14
    case noError = 0x9000
    case deviceBusy = 0x9001
    case derivingKeyError = 0x6802
    case executionError = 0x6400
    case wrongLength = 0x6700
    case emptyBuffer = 0x6982
    case outputBufferTooSmall = 0x6983
    case invalidData = 0x6984
    case conditionsNotSatisfied = 0x6985
    case transactionRejected = 0x6986
    case badKey = 0x6A80
    case invalidP1P2 = 0x6B00
    case instructionNotSupported = 0x6D00
    case wrongAppOpen = 0x6E00
    case appNotOpen = 0x6E01
    case unknownError = 0x6F00
    case signVerifyError = 0x6F01

    init(responseCode: UInt16) {
        self = .init(rawValue: responseCode) ?? .unknown
    }
}

struct LedgerResponse<T: LedgerDecodable>: LedgerDecodable {
    let code: LedgerResponseCode
    let value: T

    init(ledgerData: Data) throws {
        let responseCodeSize = 2

        guard ledgerData.count >= responseCodeSize else {
            throw LedgerError.unexpectedData("No response code")
        }

        code = LedgerResponseCode(responseCode: UInt16(bigEndianData: ledgerData.suffix(responseCodeSize)))

        guard code == .noError else {
            throw LedgerError.response(code: code)
        }

        let valueData = ledgerData.prefix(ledgerData.count - responseCodeSize)
        value = try T(ledgerData: valueData)
    }
}

extension Data: LedgerDecodable {
    init(ledgerData: Data) throws {
        self = ledgerData
    }
}

typealias LedgerSignature = Data
