import Foundation
import Operation_iOS

struct AnalyticsPendingEvent: Equatable {
    let identifier: String
    let sequence: Int64
    let name: String
    let timestamp: Date
    let payload: Data

    /// FIFO order is a lexicographic sort over `identifier`, so the sequence is zero-padded
    /// to the width of `Int64.max` (19 digits).
    static func identifier(for sequence: Int64) -> String {
        String(format: "%019lld", sequence)
    }
}

extension AnalyticsPendingEvent: Identifiable {}
