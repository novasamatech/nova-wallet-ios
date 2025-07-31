import Foundation

struct DAppAttestRequest: Codable {
    @Base64Codable var challenge: Data
    @Base64Codable var attestation: Data
    let appIntegrityId: String
}
