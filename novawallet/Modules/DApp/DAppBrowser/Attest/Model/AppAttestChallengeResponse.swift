import Foundation

struct AppAttestChallengeResponse: Codable {
    @HexCodable var challenge: Data
}
