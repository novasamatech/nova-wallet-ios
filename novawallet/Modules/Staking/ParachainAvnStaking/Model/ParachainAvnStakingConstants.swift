import Foundation
import BigInt

/// Compile-time constants for the Energy Web X parachain-staking
/// (AvN fork) integration.
///
/// The design goal is that almost nothing in this file is a hardcoded
/// numeric value. Every meaningful quantity (commission, min stake,
/// unbond delay, era length, active collator count, growth rewards)
/// is queried live against the EWX chain via Nova's existing
/// `PrimitiveConstantOperation` and `StorageRequestFactory` patterns.
///
/// The fallbacks below exist only so:
/// (a) UI code can render a placeholder label before a live query
///     completes, and
/// (b) unit tests can construct fixture values without an online runtime.
///
/// Verified live against EWX mainnet (spec version 105, 2026-04-11)
/// via `wss://public-rpc.mainnet.energywebx.com/`:
///
///   Pallet name                       ParachainStaking
///   MinNominationPerCollator (const)  1000000000000000000 wei  (1 EWT)
///   MaxNominationsPerNominator (const) 100
///   RewardPaymentDelay (const)        2 eras
///   ErasPerGrowthPeriod (const)       28 eras
///   DefaultCollatorCommission (stor)  100000000 Perbill  (10%)
///   Total staked (storage)            ~25.5M EWT
///   Era length (storage)              7200 blocks  (~24 hours @ 12s)
///   Delay (storage)                   2 eras
enum ParachainAvnStakingConstants {
    /// Pallet name as emitted by the EWX runtime metadata. Used when
    /// constructing `StorageCodingPath`, `ConstantCodingPath`, and
    /// `CallCodingPath` values. Matches Moonbeam's value but DO NOT
    /// share code between the two integrations — the call names
    /// inside the pallet differ.
    static let palletName = "ParachainStaking"

    /// Fallback minimum nomination in wei (1 EWT). The real value is
    /// read from the `MinNominationPerCollator` runtime constant at
    /// service init time. This fallback is used only if the metadata
    /// query fails. Written as an integer literal so SwiftFormat won't
    /// strip the type annotation into a force-unwrapped string literal
    /// (`BigUInt("...")` resolves ambiguously between the optional
    /// String init and the non-optional ExpressibleByStringLiteral init,
    /// which breaks the build if the linter drops `: BigUInt`).
    static let fallbackMinNominationWei: BigUInt = 1_000_000_000_000_000_000

    /// Fallback scheduled-unbond delay in eras. The real value is read
    /// from the `ParachainStaking.Delay` storage item. Exists so the
    /// Start Staking info screen can render an unstaking-time label
    /// before the storage read lands.
    static let fallbackUnbondDelayEras: UInt32 = 2

    /// Fallback era length in blocks. Real value is read from the
    /// `ParachainStaking.Era` storage item (`length` field). EWX
    /// configures this via `set_blocks_per_era` to 7200 blocks on
    /// mainnet, which is ~24 hours at the typical 12-second block time.
    static let fallbackEraBlocks: UInt32 = 7200
}
