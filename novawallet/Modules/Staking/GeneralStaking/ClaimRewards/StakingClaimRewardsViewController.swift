import UIKit
import SoraFoundation

final class StakingClaimRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingClaimRewardsViewLayout

    let presenter: StakingClaimRewardsPresenterProtocol

    init(presenter: StakingClaimRewardsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingClaimRewardsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.stakingClaimRewards(preferredLanguages: languages)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.restakeCell.titleLabel.text = R.string.localizable.stakingRestakeTitle_v2_2_0(
            preferredLanguages: languages
        )

        rootView.restakeCell.subtitleLabel.text = R.string.localizable.stakingRestakeMessage(
            preferredLanguages: languages
        )
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.accountCell.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        rootView.restakeCell.switchControl.addTarget(
            self,
            action: #selector(actionToggleClaimStrategy),
            for: .valueChanged
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }

    @objc private func actionToggleClaimStrategy() {
        presenter.toggleClaimStrategy()
    }
}

extension StakingClaimRewardsViewController: StakingClaimRewardsViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        rootView.walletCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveClaimStrategy(viewModel: StakingClaimRewardsViewMode) {
        let shouldRestake = viewModel == .restake
        rootView.restakeCell.switchControl.setOn(shouldRestake, animated: false)
    }
}

extension StakingClaimRewardsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
