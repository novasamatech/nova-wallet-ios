import UIKit
import Foundation_iOS

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

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()
        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transferableTitleLabel.text = R.string(preferredLanguages: languages).localizable.walletBalanceAvailable()

        rootView.lockAmountTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonGovLock()
        rootView.lockPeriodTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonLockingPeriod()

        let hint = R.string(preferredLanguages: languages).localizable.govVoteSetupHint()
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
