import Foundation
import Operation_iOS

public struct AnalyticsPendingEvent: Equatable {
    public let identifier: String
    public let sequence: Int64
    public let name: String
    public let timestamp: Date
    public let payload: Data

    /// FIFO order comes from the `analyticsEventsBySequence` sort descriptor, not from this
    /// string — the sequence prefix is kept only so a row dump reads in order.
    ///
    /// The random suffix is what makes the identifier safe: `sequence` restarts at 0 after
    /// `clearOperation()`, so without it a `dropOperation(ids:)` belonging to a batch that
    /// outlived an opt-out wipe would delete brand-new, unrelated rows that happen to have
    /// been allocated the same sequence numbers.
    public static func identifier(for sequence: Int64, unique: String = UUID().uuidString) -> String {
        String(format: "%019lld", sequence) + "-" + unique
    }
}

extension AnalyticsPendingEvent: Identifiable {}
