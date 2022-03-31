import Foundation
import SoraFoundation
import IrohaCrypto

protocol BeaconQRMatching {
    func match(code: String) -> BeaconConnectionInfo?
}

enum BeaconQRMatcherError: Error {
    case invalidUrl(actualUrl: String)
    case invalidDataLength(minLength: Int, actualLength: Int)
    case invalidChecksum(expected: Data, actual: Data)
}

final class BeaconQRMatcher: BeaconQRMatching {
    let logger: LoggerProtocol?

    init(logger: LoggerProtocol? = Logger.shared) {
        self.logger = logger
    }

    func match(code: String) -> BeaconConnectionInfo? {
        do {
            return try parse(code: code)
        } catch {
            logger?.error("Did receive parsing error: \(error)")
            return nil
        }
    }

    private func parse(code: String) throws -> BeaconConnectionInfo {
        guard let urlComponents = URLComponents(string: code), let queryString = urlComponents.query else {
            throw BeaconQRMatcherError.invalidUrl(actualUrl: code)
        }

        let query = try QueryDecoder().decode(BeaconQuery.self, query: queryString)

        let data = NSData(base58String: query.data) as Data
        let checksumLength = 4

        guard data.count >= checksumLength else {
            throw BeaconQRMatcherError.invalidDataLength(
                minLength: checksumLength,
                actualLength: data.count
            )
        }

        let checksumData = data.suffix(checksumLength)
        let jsonData = data.prefix(data.count - checksumLength)

        let expectedChecksumData = jsonData.sha256().sha256().prefix(checksumLength)

        guard expectedChecksumData == checksumData else {
            throw BeaconQRMatcherError.invalidChecksum(
                expected: expectedChecksumData,
                actual: checksumData
            )
        }

        return try JSONDecoder().decode(BeaconConnectionInfo.self, from: jsonData)
    }
}
