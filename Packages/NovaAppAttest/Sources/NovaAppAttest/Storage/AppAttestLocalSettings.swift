import Foundation
import Operation_iOS

public struct AppAttestKeySettings: Codable, Equatable {
    public let identifier: String
    public let keyId: String
    public let isAttested: Bool
    /// Persist before calling `attestKey`; a lost result must not cause a second attestation of the key.
    public let isAttestationSpent: Bool
    public let attemptCount: Int
    public let nextAttemptAt: Date?

    public init(
        identifier: String,
        keyId: String,
        isAttested: Bool,
        isAttestationSpent: Bool = false,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil
    ) {
        self.identifier = identifier
        self.keyId = keyId
        self.isAttested = isAttested
        self.isAttestationSpent = isAttestationSpent
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
    }

    // Defaults preserve older rows; unknown spend state is treated as spent to prevent key reuse.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        keyId = try container.decode(String.self, forKey: .keyId)
        isAttested = try container.decode(Bool.self, forKey: .isAttested)
        isAttestationSpent = try container.decodeIfPresent(Bool.self, forKey: .isAttestationSpent) ?? true
        attemptCount = try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        nextAttemptAt = try container.decodeIfPresent(Date.self, forKey: .nextAttemptAt)
    }
}

extension AppAttestKeySettings: Identifiable {}
