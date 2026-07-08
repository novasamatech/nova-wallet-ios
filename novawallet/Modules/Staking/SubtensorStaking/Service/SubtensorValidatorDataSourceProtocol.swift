import Foundation
import BigInt

/// Abstraction over whatever data source is currently serving Bittensor
/// validator numeric data (commission, stake, APR). v1 uses TaoStats REST.
/// A future Nova-indexer implementation will replace `TaoStatsValidatorDataSource`
/// via one-line DI swap in `SubtensorStakeSetupViewFactory`.
protocol SubtensorValidatorDataSourceProtocol: Sendable {
    func fetchValidatorData(netuid: UInt16) async throws -> [SubtensorValidatorData]
}

/// Data-source-agnostic validator record. The provider merges this with
/// identity metadata from `BittensorDelegatesClient` to produce the
/// display-facing `SubtensorValidator` model.
struct SubtensorValidatorData: Sendable {
    /// Decoded hotkey account id (32 bytes for substrate).
    let hotkey: AccountId
    /// Raw SS58 hotkey string for identity cross-reference keyed by the
    /// bittensor-delegates registry (which stores SS58 strings).
    let ss58: String
    /// Display name if the data source supplies one (e.g. TaoStats `name`).
    let name: String?
    /// Total hotkey stake in RAO.
    let totalStake: BigUInt
    /// Validator's own stake component in RAO.
    let ownStake: BigUInt
    /// Delegate take / commission as a fraction 0.0...1.0.
    let commission: Double
    /// Number of nominators delegating to this hotkey (if known).
    let nominatorCount: UInt32?
    /// Annualized return as a fraction 0.0...1.0; nil if unknown.
    let apr: Double?
}
