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

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()
        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonAccount()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.delegateCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.govDelegate()

        rootView.yourDelegationCell.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.govYourDelegation()

        rootView.transferableTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.walletBalanceAvailable()

        rootView.lockAmountTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonGovLock()
        rootView.undelegatingPeriodTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.govUndelegatingPeriod()

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonConfirm()
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
                for: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govTracks(),
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
