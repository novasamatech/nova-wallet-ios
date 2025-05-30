import UIKit
import Foundation_iOS

final class StakingClaimRewardsViewController: StakingGenericRewardsViewController<StakingClaimRewardsViewLayout> {
    var presenter: StakingClaimRewardsPresenterProtocol? {
        basePresenter as? StakingClaimRewardsPresenterProtocol
    }

    init(presenter: StakingClaimRewardsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func onViewDidLoad() {
        super.onViewDidLoad()

        setupHandlers()
    }

    override func onSetupLocalization() {
        super.onSetupLocalization()

        rootView.restakeCell.titleLabel.text = R.string.localizable.stakingRestakeTitle_v2_2_0(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.restakeCell.subtitleLabel.text = R.string.localizable.stakingRestakeMessage(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.restakeCell.switchControl.addTarget(
            self,
            action: #selector(actionToggleClaimStrategy),
            for: .valueChanged
        )
    }

    @objc private func actionToggleClaimStrategy() {
        presenter?.toggleClaimStrategy()
    }
}

extension StakingClaimRewardsViewController: StakingClaimRewardsViewProtocol {
    func didReceiveClaimStrategy(viewModel: StakingClaimRewardsStrategy) {
        let shouldRestake = viewModel == .restake
        rootView.restakeCell.switchControl.setOn(shouldRestake, animated: false)
    }
}
