import Foundation

/// Extends the shared `CollatorStakingConfirmViewProtocol` with a Subtensor-only
/// Nova-fee row hook. Added here so the collator staking protocol/view are
/// never modified, preserving feature isolation.
///
/// The Subtensor stake/unstake confirm presenters call `didReceiveNovaFee(viewModel:)`
/// with a non-nil value to show the row, or nil to hide it. The row is hidden by default.
protocol SubtensorStakingConfirmViewProtocol: CollatorStakingConfirmViewProtocol {
    /// Populate and show the Nova-fee row, or hide it when `viewModel` is nil.
    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?)
    /// Show/hide the "Includes 0.3% Nova Wallet fee." disclosure caption
    /// (visible whenever the fee applies — subnet with a fee address set).
    func didReceiveNovaFeeDisclaimer(visible: Bool)
}
