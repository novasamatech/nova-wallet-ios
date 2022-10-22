import UIKit
import SoraFoundation

final class ReferendumVoteConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumVoteConfirmViewLayout

    let presenter: ReferendumVoteConfirmPresenterProtocol

    private var referendumNumber: String?

    init(presenter: ReferendumVoteConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVoteConfirmViewLayout()
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

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        applyReferendumNumber()

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonSender(preferredLanguages: languages)

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

    private func applyReferendumNumber() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.govVoteSetupTitleFormat(
            referendumNumber ?? "",
            preferredLanguages: languages
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSender() {
        presenter.presentSenderDetails()
    }
}

extension ReferendumVoteConfirmViewController: ReferendumVoteConfirmViewProtocol {
    func didReceive(referendumNumber: String) {
        self.referendumNumber = referendumNumber

        applyReferendumNumber()
    }

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

    func didReceiveYourVote(viewModel: YourVoteRow.Model) {
        rootView.yourVoteView.bind(viewModel: viewModel)
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

extension ReferendumVoteConfirmViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension ReferendumVoteConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension ReferendumVoteConfirmViewController: ImportantViewProtocol {}
