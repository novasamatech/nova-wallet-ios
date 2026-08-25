import Foundation_iOS
import UIKit

final class SubtensorClaimRewardsViewController: StakingGenericRewardsViewController<SubtensorClaimRewardsViewLayout> {
    override func onSetupLocalization() {
        rootView.pendingCell.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingPendingRewards()
    }
}

extension SubtensorClaimRewardsViewController: SubtensorClaimRewardsViewProtocol {
    func didReceivePending(viewModel: BalanceViewModelProtocol?) {
        if let viewModel {
            rootView.pendingCell.isHidden = false
            rootView.pendingCell.bind(viewModel: viewModel)
        } else {
            rootView.pendingCell.isHidden = true
        }
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }
}
