import Foundation
import Operation_iOS

public struct AnalyticsPendingEvent: Equatable {
    public let identifier: String
    public let sequence: Int64
    public let name: String
    public let timestamp: Date
    public let payload: Data

    public static func identifier(for sequence: Int64, unique: String = UUID().uuidString) -> String {
        String(format: "%019lld", sequence) + "-" + unique
    }
}

extension AnalyticsPendingEvent: Identifiable {}
