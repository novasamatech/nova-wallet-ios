import UIKit
import SoraFoundation

final class GovernanceUnlockConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceUnlockConfirmViewLayout

    let presenter: GovernanceUnlockConfirmPresenterProtocol

    init(
        presenter: GovernanceUnlockConfirmPresenterProtocol,
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
        view = GovernanceUnlockConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonUnlock(preferredLanguages: languages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: languages
        )

        rootView.accountCell.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: languages
        )

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transferableTitleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )

        rootView.lockAmountTitleLabel.text = R.string.localizable.commonGovLock(
            preferredLanguages: languages
        )

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension GovernanceUnlockConfirmViewController: GovernanceUnlockConfirmViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.transferableCell.bind(viewModel: viewModel)
    }

    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.lockedAmountCell.bind(viewModel: viewModel)
    }

    func didReceiveRemainedLock(viewModel: GovernanceRemainedLockViewModel?) {
        if let viewModel = viewModel {

        } else {
            rootView.hintsView.bind(texts: [""])
        }
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension GovernanceUnlockConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
