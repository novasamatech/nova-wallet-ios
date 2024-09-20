import UIKit
import SoraFoundation

class BaseReferendumVoteConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseReferendumVoteConfirmViewLayout

    private let presenter: BaseReferendumVoteConfirmPresenterProtocol

    init(
        presenter: BaseReferendumVoteConfirmPresenterProtocol,
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
        view = BaseReferendumVoteConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )

        rootView.accountCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(preferredLanguages: languages)

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transferableTitleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )

        rootView.lockAmountTitleLabel.text = R.string.localizable.commonGovLock(preferredLanguages: languages)
        rootView.lockPeriodTitleLabel.text = R.string.localizable.commonLockingPeriod(preferredLanguages: languages)

        let hint = R.string.localizable.govVoteSetupHint(preferredLanguages: languages)
        rootView.hintsView.bind(texts: [hint])

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSender() {
        presenter.presentSenderDetails()
    }
}

// MARK: BaseReferendumVoteConfirmViewProtocol

extension BaseReferendumVoteConfirmViewController: BaseReferendumVoteConfirmViewProtocol {
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

    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel) {
        rootView.lockedPeriodCell.bind(viewModel: viewModel)
    }
}

// MARK: LoadableViewProtocol

extension BaseReferendumVoteConfirmViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

// MARK: Localizable

extension BaseReferendumVoteConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: ImportantViewProtocol

extension BaseReferendumVoteConfirmViewController: ImportantViewProtocol {}
