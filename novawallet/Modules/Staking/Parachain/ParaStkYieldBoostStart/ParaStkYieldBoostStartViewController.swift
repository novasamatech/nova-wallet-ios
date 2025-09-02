import UIKit
import Foundation_iOS

final class ParaStkYieldBoostStartViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = ParaStkYieldBoostStartViewLayout

    let presenter: ParaStkYieldBoostStartPresenterProtocol

    private var periodViewModel: UInt?
    private var thresholdViewModel: String?

    init(
        presenter: ParaStkYieldBoostStartPresenterProtocol,
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
        view = ParaStkYieldBoostStartViewLayout()
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

        rootView.acceptTermsView.addTarget(
            self,
            action: #selector(actionAcceptTerms),
            for: .valueChanged
        )

        rootView.senderCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonYieldBoost(preferredLanguages: languages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.senderCell.titleLabel.text = R.string.localizable.commonSender(preferredLanguages: languages)

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.collatorCell.titleLabel.text = R.string.localizable.parachainStakingCollator(
            preferredLanguages: languages
        )

        rootView.stakingTypeCell.titleLabel.text = R.string.localizable.stakingTitle(
            preferredLanguages: languages
        )

        rootView.stakingTypeCell.bind(
            details: R.string.localizable.withYieldBoost(preferredLanguages: languages)
        )

        rootView.thresholdCell.titleLabel.text = R.string.localizable.yieldBoostThreshold(preferredLanguages: languages)

        rootView.periodCell.titleLabel.text = R.string.localizable.yieldBoostPeriodTitle(preferredLanguages: languages)

        applyPeriodViewModel()
        applyConfirmationViewModel()

        updateActionButtonState()
    }

    private func applyPeriodViewModel() {
        let title = periodViewModel?.localizedDaysPeriod(for: selectedLocale).firstLetterCapitalized() ?? ""
        rootView.periodCell.bind(details: title)
    }

    private func applyConfirmationViewModel() {
        guard
            let periodViewModel = periodViewModel,
            let thresholdViewModel = thresholdViewModel else {
            return
        }

        let period = periodViewModel.localizedDaysPeriod(for: selectedLocale)

        rootView.acceptTermsView.controlContentView.detailsLabel.text = R.string.localizable.yieldBoostTermsMessage(
            period,
            thresholdViewModel,
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func updateActionButtonState() {
        if rootView.acceptTermsView.isChecked {
            let title = R.string.localizable.commonConfirm(preferredLanguages: selectedLocale.rLanguages)

            rootView.actionLoadableView.actionButton.applyState(title: title, enabled: true)
        } else {
            let title = R.string.localizable.commonAcceptTerms(preferredLanguages: selectedLocale.rLanguages)

            rootView.actionLoadableView.actionButton.applyState(title: title, enabled: false)
        }
    }

    @objc private func actionAcceptTerms() {
        updateActionButtonState()
    }

    @objc private func actionConfirm() {
        presenter.submit()
    }

    @objc private func actionSender() {
        presenter.showSenderActions()
    }
}

extension ParaStkYieldBoostStartViewController: ParaStkYieldBoostStartViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel) {
        rootView.senderCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveCollator(viewModel: DisplayAddressViewModel) {
        rootView.collatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveThreshold(viewModel: String) {
        thresholdViewModel = viewModel

        rootView.thresholdCell.bind(details: viewModel)

        applyConfirmationViewModel()
    }

    func didReceivePeriod(viewModel: UInt) {
        periodViewModel = viewModel

        applyPeriodViewModel()
        applyConfirmationViewModel()
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension ParaStkYieldBoostStartViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
