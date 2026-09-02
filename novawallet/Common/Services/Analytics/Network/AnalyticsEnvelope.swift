import Foundation

struct AnalyticsEnvelope: Encodable {
    let schemaVersion: Int
    let platform: String
    let appVersion: String
    let installId: String
    let sessionId: String
    let sentAt: String
    let events: [AnalyticsEventRemote]

    enum CodingKeys: String, CodingKey {
        /// SwiftLint's identifier_name rejects a one-letter property, so the wire key
        /// "v" is reached through an explicit mapping.
        case schemaVersion = "v"
        case platform
        case appVersion = "app_version"
        case installId = "install_id"
        case sessionId = "session_id"
        case sentAt = "sent_at"
        case events
    }
}
