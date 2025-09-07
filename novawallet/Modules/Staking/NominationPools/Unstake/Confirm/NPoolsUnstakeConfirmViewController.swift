import UIKit
import Foundation_iOS

final class NPoolsUnstakeConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = NPoolsUnstakeConfirmViewLayout

    let presenter: NPoolsUnstakeConfirmPresenterProtocol

    init(presenter: NPoolsUnstakeConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsUnstakeConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingUnbond_v190()

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirm()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonWallet()

        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonAccount()

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
        presenter.proceed()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }
}

extension NPoolsUnstakeConfirmViewController: NPoolsUnstakeConfirmViewProtocol {
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

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }
}

extension NPoolsUnstakeConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
