import UIKit
import Foundation_iOS

final class CollatorStakingRedeemViewController: UIViewController, ViewHolder {
    typealias RootViewType = CollatorStakingRedeemViewLayout

    let presenter: CollatorStakingRedeemPresenterProtocol

    init(
        presenter: CollatorStakingRedeemPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CollatorStakingRedeemViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.stakingRedeem(preferredLanguages: languages)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale
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
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }
}

extension CollatorStakingRedeemViewController: CollatorStakingRedeemViewProtocol {
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

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension CollatorStakingRedeemViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
