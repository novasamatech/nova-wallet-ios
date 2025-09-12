import UIKit
import Foundation_iOS

final class NominationPoolBondMoreConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = NominationPoolBondMoreConfirmViewLayout

    let presenter: NominationPoolBondMoreConfirmPresenterProtocol

    init(
        presenter: NominationPoolBondMoreConfirmPresenterProtocol,
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
        view = NominationPoolBondMoreConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.stakingBondMore_v190()

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonConfirm()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()

        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

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

extension NominationPoolBondMoreConfirmViewController: NominationPoolBondMoreConfirmViewProtocol {
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

extension NominationPoolBondMoreConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension NominationPoolBondMoreConfirmViewController: ImportantViewProtocol {}
