import Foundation
import CommonCrypto

/// Deliberately `internal` and deliberately a copy of the app's `Common/Crypto/Data+Sha256.swift`.
///
/// The app keeps its own copy for the eight call sites that have nothing to do with
/// attestation, and this package cannot see it. Left `public`, the two identically shaped
/// extensions would both be visible in any app file that imports `NovaAppAttest` and every
/// `data.sha256()` there would become ambiguous, so this one stays inside the module.
extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }

        return Data(hash)
    }
}
