import Foundation

/// Runtime constant paths for Energy Web X's `ParachainStaking` pallet.
/// Verified live against EWX mainnet runtime metadata v15 (spec version
/// 105, 2026-04-11).
///
/// All of these are `ConstantCodingPath` values intended to be fed into
/// Nova's existing `PrimitiveConstantOperation.operation(for:dependingOn:)`
/// at service init time so the real values from chain metadata are used,
/// not hardcoded Swift literals.
extension ParachainAvn {
    /// `u128` — minimum nomination a user can place on a single collator.
    /// Current value: 1 EWT (10^18 wei). Used to gate the stake-amount
    /// input field.
    static var minNominationPerCollator: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            constantName: "MinNominationPerCollator"
        )
    }

    /// `u32` — maximum number of distinct collators a single user may
    /// nominate. Current value: 100.
    static var maxNominationsPerNominator: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            constantName: "MaxNominationsPerNominator"
        )
    }

    /// `u32` — number of eras that must pass after a reward period ends
    /// before the payout is released. Current value: 2.
    static var rewardPaymentDelay: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            constantName: "RewardPaymentDelay"
        )
    }

    /// `u32` — length of each growth period in eras. Rewards accumulate
    /// for this many eras before being distributed. Current value: 28.
    static var erasPerGrowthPeriod: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            constantName: "ErasPerGrowthPeriod"
        )
    }

    /// `u32` — maximum number of top (counted) nominations per collator.
    /// Current value: 300. Used to pre-validate the
    /// `candidate_nomination_count` arg to `nominate`.
    static var maxTopNominationsPerCandidate: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: ParachainAvnStakingConstants.palletName,
            constantName: "MaxTopNominationsPerCandidate"
        )
    }
}
