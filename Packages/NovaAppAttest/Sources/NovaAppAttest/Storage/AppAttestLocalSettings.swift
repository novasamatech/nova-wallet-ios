import Foundation
import Operation_iOS

public struct AppAttestKeySettings: Codable, Equatable {
    public let identifier: String
    public let keyId: String
    public let isAttested: Bool
    public let attemptCount: Int
    public let nextAttemptAt: Date?

    public init(
        identifier: String,
        keyId: String,
        isAttested: Bool,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil
    ) {
        self.identifier = identifier
        self.keyId = keyId
        self.isAttested = isAttested
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
    }

    // Rows written before the backoff fields existed must keep decoding, or every install
    // upgrading into this version silently mints a new App Attest key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        keyId = try container.decode(String.self, forKey: .keyId)
        isAttested = try container.decode(Bool.self, forKey: .isAttested)
        attemptCount = try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        nextAttemptAt = try container.decodeIfPresent(Date.self, forKey: .nextAttemptAt)
    }
}

extension AppAttestKeySettings: Identifiable {}
