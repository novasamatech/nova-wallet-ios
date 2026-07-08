import Foundation

/// Data for the TAO staking dashboard screen, scoped to the entry netuid
/// (root or a specific subnet) the user tapped from the multistaking
/// dashboard.
///
/// Layout it powers:
///   - "Your stake" card  → `totalStakeRow`
///   - Action list         → fixed: Stake more / Unstake
///   - "Your validator(s)" card → `validatorRows`
///   - "Staking info" card → `info`
struct SubtensorStakingDashboardViewModel {
    /// Single aggregated stake for the entry netuid (e.g. all root TAO,
    /// or all SN8 alpha). Empty when the user has no positions on this
    /// netuid; the view falls back to its empty state in that case.
    let totalStakeRow: SubtensorStakeAmountsView.Row?

    /// Title for the validator card — "Your validator" / "Your validators".
    let validatorsTitle: String
    let validatorRows: [SubtensorPositionViewModel]

    let info: SubtensorStakingInfoView.Model
}
