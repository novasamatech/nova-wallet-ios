import Foundation
import BigInt

/// A single (coldkey, hotkey, netuid) stake position. For v1 we only
/// surface netuid=0 positions; v2 will surface all netuids.
struct SubtensorStakePosition {
    /// The user's wallet account (the "coldkey" in Bittensor terminology).
    let coldkey: AccountId

    /// Validator target (the "hotkey" in Bittensor terminology).
    let hotkey: AccountId

    /// Always 0 for v1.
    let netuid: UInt16

    /// Amount of stake in position (in RAO for root, alpha for subnets).
    let amount: BigUInt

    /// The validator's identity name, if known. Allows display as
    /// "Staked with <name>" or "Staked with 5E2L...x4" fallback.
    let validatorIdentity: String?
}
