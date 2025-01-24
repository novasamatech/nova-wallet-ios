import Foundation

final class CollatorStakingInfoViewController: ValidatorInfoViewController {
    override func applyTitle() {
        title = R.string.localizable.parastkCollatorInfo(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    override func addOversubscriptionAlertIfNeeded(for model: ValidatorInfoViewModel.Staking) {
        if case let .elected(exposure) = model.status, exposure.oversubscribed {
            let message: String = R.string.localizable.parastkCollatorInfoNotRewarded(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.addWarningView(message: message)
        }
    }

    override func applyAccountView(from viewModel: ValidatorInfoViewModel) {
        let accountView = rootView.addIdentityAccountView(for: viewModel.account.displayAddress())

        accountView.addTarget(self, action: #selector(actionAccountOptions), for: .touchUpInside)
    }

    override func applyNominatorsView(from exposure: ValidatorInfoViewModel.Exposure) {
        let delegatorsTitle = R.string.localizable.commonParastkDelegators(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.addNominatorsView(exposure, title: delegatorsTitle)
    }

    override func applyEstimatedReward(_ estimatedReward: String) {
        if let stakingTableView = rootView.stakingTableView {
            rootView.addTitleValueView(
                for: R.string.localizable.stakingValidatorEstimatedReward(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: estimatedReward,
                to: stakingTableView
            )
        }
    }

    @objc private func actionAccountOptions() {
        presenter.presentAccountOptions()
    }
}

extension CollatorStakingInfoViewController: CollatorStakingInfoViewProtocol {}
