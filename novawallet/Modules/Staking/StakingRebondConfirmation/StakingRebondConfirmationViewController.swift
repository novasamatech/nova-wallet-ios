import UIKit
import SoraFoundation

final class StakingRebondConfirmationViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = StakingRebondConfirmationLayout

    let presenter: StakingRebondConfirmationPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var confirmationViewModel: StakingRebondConfirmationViewModel?
    private var amountViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    init(
        presenter: StakingRebondConfirmationPresenterProtocol,
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
        view = StakingRebondConfirmationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureActions()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingRebond(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale

        applyAmountViewModel()
        applyFeeViewModel()
        applyConfirmationViewModel()
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
        rootView.accountCell.bind(viewModel: confirmViewModel.addressViewModel.cellViewModel)
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionSelectAccount() {
        presenter.selectAccount()
    }
}

extension StakingRebondConfirmationViewController: StakingRebondConfirmationViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel) {
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
}

extension StakingRebondConfirmationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
