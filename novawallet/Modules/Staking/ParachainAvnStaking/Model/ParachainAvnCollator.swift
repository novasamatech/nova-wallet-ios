import Foundation
import BigInt

/// View-model struct describing a single EWX collator ("candidate"),
/// populated entirely from live on-chain queries. No value in this
/// struct comes from a third-party API or a hardcoded Swift literal:
///
///   accountId       ← `parachainStaking.candidatePool` entries (owner)
///   identity        ← `identity.identityOf(accountId)` (optional)
///   totalStake      ← `parachainStaking.candidateInfo(accountId).totalCounted`
///   ownStake        ← `parachainStaking.candidateInfo(accountId).bond`
///   delegatedStake  ← totalStake - ownStake (derived)
///   nominationCount ← `parachainStaking.candidateInfo(accountId).nominationCount`
///   commission      ← `parachainStaking.defaultCollatorCommission.current`
///                     (global Perbill, applies to all collators)
///   estimatedApr    ← derived from `parachainStaking.growth` accumulators
///                     via `ParachainAvnAprCalculator`
///   isActive        ← membership in `parachainStaking.selectedCandidates`
struct ParachainAvnCollator {
    let accountId: AccountId
    let identity: String?
    let totalStake: BigUInt
    let ownStake: BigUInt
    let delegatedStake: BigUInt
    let nominationCount: UInt32
    /// Commission as a decimal fraction in [0, 1]. EWX commission is
    /// global, so every collator in a given fetch carries the same
    /// value — the field is per-collator here for future-proofing
    /// against a pallet upgrade that introduces per-collator rates.
    let commission: Decimal
    /// Client-computed APR estimate as a decimal fraction in [0, 1].
    /// `nil` when the current growth period has accumulated fewer
    /// than the minimum number of eras the calculator considers
    /// reliable (avoids wild swings from a single-era sample).
    let estimatedApr: Decimal?
    let isActive: Bool
}
