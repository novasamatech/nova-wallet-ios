import Foundation

struct AppAttestChallengeResponse: Codable {
    @Base64Codable var challenge: Data
}
