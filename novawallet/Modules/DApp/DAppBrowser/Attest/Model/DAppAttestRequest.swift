import Foundation

struct DAppAttestRequest: Codable {
    let challenge: String
    @Base64Codable var deviceToken: Data
    @Base64Codable var attestation: Data
    let appIntegrityId: String
    let bundleId: String
}
