import Foundation
import Operation_iOS

public struct AppAttestKeySettings: Codable, Equatable {
    public let identifier: String
    public let keyId: String
    public let isAttested: Bool
    /// Apple attests a key once. Set before `attestKey` is called, so a result lost on the way back
    /// still retires the key instead of being re-attested into a `DCError.invalidKey`.
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

    // Rows written before the backoff fields existed must keep decoding, or every install
    // upgrading into this version silently mints a new App Attest key. A row predating
    // `isAttestationSpent` has an unknown spend state, and only "spent" is a recoverable guess.
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
