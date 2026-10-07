import UIKit
import Foundation_iOS

final class SubtensorClaimRewardsViewController: StakingGenericRewardsViewController<SubtensorClaimRewardsViewLayout> {
    var presenter: SubtensorClaimRewardsPresenterProtocol? {
        basePresenter as? SubtensorClaimRewardsPresenterProtocol
    }

    init(presenter: SubtensorClaimRewardsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func onViewDidLoad() {
        super.onViewDidLoad()

        rootView.validatorCell.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
    }

    override func onSetupLocalization() {
        super.onSetupLocalization()

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.validatorCell.titleLabel.text = strings.stakingCommonValidator()
        rootView.stakeAfterCell.titleLabel.text = strings.stakingSubtensorUiStakeAfter()
    }
}

private extension SubtensorClaimRewardsViewController {
    func bindAction(isEnabled: Bool) {
        if isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }

        rootView.actionButton.isUserInteractionEnabled = isEnabled
        rootView.actionButton.invalidateLayout()
    }

    func bindSigningHint(_ hint: String?) {
        rootView.signingHintView.isHidden = hint == nil

        if let hint {
            rootView.signingHintView.bindHint(text: hint, icon: R.image.iconWatchOnly())
        }
    }

    @objc func actionSelectValidator() {
        presenter?.selectValidator()
    }
}

extension SubtensorClaimRewardsViewController: SubtensorClaimRewardsViewProtocol {
    func didReceiveValidator(viewModel: DisplayAddressViewModel) {
        rootView.validatorCell.detailsLabel.lineBreakMode = viewModel.lineBreakMode
        rootView.validatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceive(viewModel: SubtensorClaimRewardsViewModel) {
        didReceiveAmount(viewModel: viewModel.amount)
        didReceiveFee(viewModel: viewModel.networkFee)

        rootView.stakeAfterCell.isHidden = viewModel.stakeAfter == nil
        rootView.stakeAfterCell.bind(details: viewModel.stakeAfter ?? "")

        rootView.noticeView.contentView.detailsLabel.text = viewModel.notice

        bindSigningHint(viewModel.signingHint)
        bindAction(isEnabled: viewModel.isActionEnabled)
    }
}
