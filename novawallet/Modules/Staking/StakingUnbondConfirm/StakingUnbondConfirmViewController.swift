import UIKit
import SoraFoundation

final class StakingUnbondConfirmViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = StakingUnbondConfirmLayout

    let presenter: StakingUnbondConfirmPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var confirmationViewModel: StakingUnbondConfirmViewModel?
    private var amountViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var bondingDuration: LocalizableResource<String>?

    init(
        presenter: StakingUnbondConfirmPresenterProtocol,
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
        view = StakingUnbondConfirmLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureActions()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingUnbond_v190(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale

        applyAmountViewModel()
        applyFeeViewModel()
        applyConfirmationViewModel()
        applyBondingDuration()
    }

    private func configureActions() {
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

    private func applyAmountViewModel() {
        guard let viewModel = amountViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.amountView.bind(viewModel: viewModel)
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    private func applyConfirmationViewModel() {
        guard let confirmViewModel = confirmationViewModel else {
            return
        }

        rootView.walletCell.bind(viewModel: confirmViewModel.walletViewModel.cellViewModel)
        rootView.accountCell.bind(viewModel: confirmViewModel.accountViewModel.cellViewModel)
    }

    private func applyBondingDuration() {
        let value = bondingDuration?.value(for: selectedLocale)
        rootView.hintListView.bondingDuration = value
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }
}

extension StakingUnbondConfirmViewController: StakingUnbondConfirmViewProtocol {
    func didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel) {
        confirmationViewModel = viewModel
        applyConfirmationViewModel()
    }

    func didReceiveAmount(viewModel: LocalizableResource<BalanceViewModelProtocol>) {
        amountViewModel = viewModel
        applyAmountViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }

    func didReceiveBonding(duration: LocalizableResource<String>) {
        bondingDuration = duration
        applyBondingDuration()
    }

    func didSetShouldResetRewardsDestination(value: Bool) {
        rootView.hintListView.shouldResetRewardDestination = value
    }
}

extension StakingUnbondConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
