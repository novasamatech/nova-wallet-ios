import UIKit
import Foundation_iOS

final class CollatorStakingConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = CollatorStakingConfirmViewLayout

    let presenter: CollatorStakingConfirmPresenterProtocol

    let localizableTitle: LocalizableResource<String>

    init(
        presenter: CollatorStakingConfirmPresenterProtocol,
        localizableTitle: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizableTitle = localizableTitle

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CollatorStakingConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = localizableTitle.value(for: selectedLocale)

        rootView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirm()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonWallet()

        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonAccount()

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.collatorCell.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.parachainStakingCollator()
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

        rootView.collatorCell.addTarget(
            self,
            action: #selector(actionSelectCollator),
            for: .touchUpInside
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }

    @objc private func actionSelectCollator() {
        presenter.selectCollator()
    }
}

extension CollatorStakingConfirmViewController: CollatorStakingConfirmViewProtocol {
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

    func didReceiveCollator(viewModel: DisplayAddressViewModel) {
        rootView.collatorCell.titleLabel.lineBreakMode = viewModel.lineBreakMode
        rootView.collatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintListView.bind(texts: viewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension CollatorStakingConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
