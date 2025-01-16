import UIKit
import Foundation_iOS

final class GovernanceDelegateConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceDelegateConfirmViewLayout

    let presenter: GovernanceDelegateConfirmPresenterProtocol

    let delegateTitle: LocalizableResource<String>

    init(
        presenter: GovernanceDelegateConfirmPresenterProtocol,
        delegateTitle: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.delegateTitle = delegateTitle

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceDelegateConfirmViewLayout()
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
            action: #selector(actionSenderOptions),
            for: .touchUpInside
        )

        rootView.delegateCell.addTarget(
            self,
            action: #selector(actionDelegateOptions),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = delegateTitle.value(for: selectedLocale)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(preferredLanguages: languages)

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.delegateCell.titleLabel.text = R.string.localizable.govDelegate(
            preferredLanguages: languages
        )

        rootView.yourDelegationCell.titleLabel.text = R.string.localizable.govYourDelegation(
            preferredLanguages: languages
        )

        rootView.transferableTitleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )

        rootView.lockAmountTitleLabel.text = R.string.localizable.commonGovLock(preferredLanguages: languages)
        rootView.undelegatingPeriodTitleLabel.text = R.string.localizable.govUndelegatingPeriod(
            preferredLanguages: languages
        )

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSenderOptions() {
        presenter.presentSenderAccount()
    }

    @objc private func actionDelegateOptions() {
        presenter.presentDelegateAccount()
    }

    @objc private func actionTracks() {
        presenter.presentTracks()
    }
}

extension GovernanceDelegateConfirmViewController: GovernanceDelegateConfirmViewProtocol {
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

    func didReceiveDelegate(viewModel: GovernanceDelegateStackCell.Model) {
        rootView.delegateCell.bind(viewModel: viewModel)
    }

    func didReceiveTracks(viewModel: GovernanceTracksViewModel) {
        if
            let cell = rootView.addTracksCell(
                for: R.string.localizable.govTracks(preferredLanguages: selectedLocale.rLanguages),
                viewModel: viewModel
            ) {
            cell.addTarget(self, action: #selector(actionTracks), for: .touchUpInside)
        }
    }

    func didReceiveYourDelegation(viewModel: GovernanceYourDelegationViewModel) {
        rootView.yourDelegationCell.topValueLabel.text = viewModel.votes
        rootView.yourDelegationCell.bottomValueLabel.text = viewModel.conviction
    }

    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.transferableCell.bind(viewModel: viewModel)
    }

    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.lockedAmountCell.bind(viewModel: viewModel)
    }

    func didReceiveUndelegatingPeriod(viewModel: String) {
        rootView.undelegatingPeriodCell.valueLabel.text = viewModel
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintsView.bind(texts: viewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension GovernanceDelegateConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
