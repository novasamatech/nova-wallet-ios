import Foundation
import BigInt

/// Fallback data source used when no real provider is configured.
/// Returns an empty array so `SubtensorValidatorProvider` falls back to
/// identity-only rows with zero numeric values (the behaviour the Phase A
/// stub already exercised).
struct StubSubtensorValidatorDataSource: SubtensorValidatorDataSourceProtocol {
    func fetchValidatorData(netuid _: UInt16) async throws -> [SubtensorValidatorData] {
        []
    }
}
