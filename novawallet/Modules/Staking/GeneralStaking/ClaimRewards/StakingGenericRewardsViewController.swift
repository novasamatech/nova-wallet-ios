import UIKit
import Foundation_iOS

typealias StakingBaseRewardsViewController = StakingGenericRewardsViewController<StakingGenericRewardsViewLayout>

class StakingGenericRewardsViewController<V: StakingGenericRewardsViewLayout>: UIViewController, ViewHolder {
    typealias RootViewType = V

    let basePresenter: StakingGenericRewardsPresenterProtocol

    init(
        basePresenter: StakingGenericRewardsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.basePresenter = basePresenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RootViewType()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        onViewDidLoad()

        basePresenter.setup()
    }

    func onViewDidLoad() {}
    func onSetupLocalization() {}

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

        onSetupLocalization()
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
    }

    @objc private func actionConfirm() {
        basePresenter.confirm()
    }

    @objc private func actionSelectAccount() {
        basePresenter.selectAccount()
    }
}

extension StakingGenericRewardsViewController: StakingGenericRewardsViewProtocol {
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
}

extension StakingGenericRewardsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
