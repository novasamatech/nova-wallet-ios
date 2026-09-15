import Foundation
import Operation_iOS

public struct AnalyticsPendingEvent: Equatable {
    public let identifier: String
    /// A bare UUID for the events endpoint; `identifier` includes a prefix used only for queue ordering.
    public let eventId: String
    public let sequence: Int64
    public let name: String
    public let timestamp: Date
    public let payload: Data
    public let consentEpoch: Int

    public static func identifier(for sequence: Int64, unique: String = UUID().uuidString) -> String {
        String(format: "%019lld", sequence) + "-" + unique
    }

    public static func eventId() -> String {
        UUID().uuidString.lowercased()
    }
}

extension AnalyticsPendingEvent: Identifiable {}
