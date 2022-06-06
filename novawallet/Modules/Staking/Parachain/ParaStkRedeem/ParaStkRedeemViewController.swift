import UIKit
import SoraFoundation

final class ParaStkRedeemViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkRedeemViewLayout

    let presenter: ParaStkRedeemPresenterProtocol

    init(presenter: ParaStkRedeemPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkRedeemViewLayout()
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

extension ParaStkRedeemViewController: ParaStkRedeemViewProtocol {
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

extension ParaStkRedeemViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
