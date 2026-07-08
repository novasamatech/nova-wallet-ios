import Foundation

/// Storage item paths for Energy Web X's `ParachainStaking` pallet
/// (AvN fork). Verified live against EWX mainnet runtime metadata v15
/// (spec version 105, 2026-04-11).
///
/// These paths are DELIBERATELY separate from
/// `StorageCodingPath+ParachainStaking.swift` (the Moonbeam variant)
/// even though the pallet string matches and some item names overlap.
/// Isolating them makes the ownership explicit and keeps ParachainAvn
/// from accidentally depending on Moonbeam types.
extension ParachainAvn {
    /// `Vec<Bond>` — all registered candidates and their self-bond.
    /// Shape per entry: `{ owner: AccountId, amount: u128 }`.
    static var candidatePoolPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "CandidatePool"
        )
    }

    /// `Map<AccountId, CandidateMetadata>` — per-candidate detail:
    /// `bond`, `nominationCount`, `totalCounted`,
    /// `lowestTopNominationAmount`, `topCapacity`, `status`, etc.
    static var candidateInfoPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "CandidateInfo"
        )
    }

    /// `Vec<AccountId>` — the collator set elected for the current era.
    static var selectedCandidatesPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "SelectedCandidates"
        )
    }

    /// `u32` — maximum active collator slots. Currently 20 on mainnet.
    static var totalSelectedPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "TotalSelected"
        )
    }

    /// `u128` — total staked amount across all candidates + nominators.
    static var totalPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "Total"
        )
    }

    /// `EraInfo` — current era number, first block, and length.
    /// Shape: `{ current: u32, first: u64, length: u32 }`.
    static var eraPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "Era"
        )
    }

    /// `u32` — scheduled-unbond / revoke delay in eras. Currently 2.
    /// Stored (not a runtime constant) so governance can adjust via
    /// `set_admin_setting`.
    static var delayPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "Delay"
        )
    }

    /// `CommissionSetting` — global collator commission as Perbill.
    /// Shape: `{ current: Perbill, scheduled: Option<Perbill> }`.
    /// Currently 10% (100_000_000 Perbill) on mainnet.
    static var defaultCollatorCommissionPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "DefaultCollatorCommission"
        )
    }

    /// `Map<u32, GrowthInfo>` — reward accumulation per growth period.
    /// Shape per entry:
    /// `{ numberOfAccumulations: u32, totalStakeAccumulated: u128,
    ///    totalStakerReward: u128, totalPoints: u32,
    ///    collatorScores: Vec<CollatorScore>, txId, triggered }`.
    /// Used for live APR estimation.
    static var growthPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "Growth"
        )
    }

    /// `{ startEraIndex: u32, index: u32 }` — current growth period.
    static var growthPeriodPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "GrowthPeriod"
        )
    }

    /// `Map<AccountId, NominatorState>` — per-user delegation list
    /// and amounts. Used for "your position" rendering.
    static var nominatorStatePath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "NominatorState"
        )
    }

    /// `Map<AccountId, Vec<ScheduledRequest>>` — pending unbond / revoke
    /// requests keyed by candidate.
    static var nominationScheduledRequestsPath: StorageCodingPath {
        StorageCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            itemName: "NominationScheduledRequests"
        )
    }
}
