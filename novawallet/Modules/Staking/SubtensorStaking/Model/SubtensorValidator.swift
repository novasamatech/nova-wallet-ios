import Foundation
import BigInt

/// UI-level model for a Bittensor validator (hotkey) on a given subnet.
/// For v1, `netuid` is always 0 (root). v2 will carry user-selected netuid.
struct SubtensorValidator {
    let hotkey: AccountId
    let netuid: UInt16

    /// Friendly name from bittensor-delegates registry, or nil if unknown.
    let identity: String?
    let url: String?
    let description: String?

    /// Total stake weight on this hotkey (in RAO for root).
    let totalStake: BigUInt

    /// Validator's own stake component.
    let ownStake: BigUInt

    /// Delegated stake from all nominators.
    let delegatedStake: BigUInt

    /// Delegate take / commission as a fraction 0.0...1.0 (not percent).
    let commission: Double

    /// Number of nominators delegating to this hotkey (v1: may be nil).
    let nominatorCount: UInt32?

    /// Minimum delegation amount from chain runtime constant. nil if not yet fetched.
    let minDelegation: BigUInt?

    /// Annualized return as a fraction 0.0...1.0; nil when the data source
    /// can't supply it (e.g. validator outside the TaoStats sample). APR is
    /// reported post-commission — what the delegator actually realized over
    /// the last 30 days.
    let apr: Double?
}
