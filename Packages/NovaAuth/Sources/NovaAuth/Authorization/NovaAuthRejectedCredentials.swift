import Foundation
import CryptoKit

struct NovaAuthRejectedCredentials {
    private var deadlines: [Data: NovaAuthTime] = [:]

    mutating func reject(_ record: NovaAuthTokenRecord) {
        let lifetime = record.expiresAt.subtractingReportingOverflow(record.issuedAt)
        guard !lifetime.overflow else { return }
        let deadline = record.issuanceStart.continuousSeconds + Double(lifetime.partialValue)
        deadlines[Data(SHA256.hash(data: Data(record.accessToken.utf8)))] =
            NovaAuthTime(bootID: record.issuanceStart.bootID, continuousSeconds: deadline)
    }

    mutating func check(_ record: NovaAuthTokenRecord, now: NovaAuthTime) throws {
        deadlines = deadlines.filter {
            $0.value.bootID == now.bootID && $0.value.continuousSeconds > now.continuousSeconds
        }
        let fingerprint = Data(SHA256.hash(data: Data(record.accessToken.utf8)))
        guard deadlines[fingerprint] == nil else { throw NovaAuthError.credentialUnavailable }
    }
}
