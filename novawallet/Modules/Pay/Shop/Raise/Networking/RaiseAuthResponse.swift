import Foundation

struct RaiseNonceAttributes: Decodable {
    @HexCodable var nonce: Data
}

struct RaiseAuthToken: Codable {
    enum CodingKeys: String, CodingKey {
        case token = "access_token"
        case expiresAt = "expires_at"
    }

    let token: String
    let expiresAt: Int

    var isExpired: Bool {
        TimeInterval(expiresAt) <= Date.now.timeIntervalSince1970
    }

    func expiringIn(timeInterval: TimeInterval) -> Bool {
        let expirationDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
        return expirationDate.timeIntervalSinceNow <= timeInterval
    }
}
