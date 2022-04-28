import UIKit
import SoraFoundation

final class StakingPayoutConfirmationViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = StakingPayoutConfirmationViewLayout

    let presenter: StakingPayoutConfirmationPresenterProtocol

    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var viewModel: LocalizableResource<PayoutConfirmViewModel>?
    private var amountViewModel: LocalizableResource<BalanceViewModelProtocol>?

    init(
        presenter: StakingPayoutConfirmationPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
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
        view = StakingPayoutConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.actionButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        rootView.accountCell.addTarget(self, action: #selector(actionAccount), for: .touchUpInside)

        setupLocalization()
        presenter.setup()
    }

    // MARK: - Private functions

    @objc private func confirmAction() {
        presenter.proceed()
    }

    @objc private func actionAccount() {
        presenter.presentAccountOptions()
    }
}

// MARK: - Localizible

extension StakingPayoutConfirmationViewController: Localizable {
    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable.stakingPayoutTitle(preferredLanguages: languages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: languages
        )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: languages
        )

        applyFeeViewModel()
        applyConfirmationViewModel()
        applyAmountViewModel()
    }

    func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func applyConfirmationViewModel() {
        guard let viewModel = viewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.walletCell.bind(viewModel: viewModel.walletViewModel.cellViewModel)
        rootView.accountCell.bind(viewModel: viewModel.accountViewModel.cellViewModel)
    }

    func applyAmountViewModel() {
        guard let viewModel = amountViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.amountView.bind(viewModel: viewModel)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

// MARK: - StakingPayoutConfirmationViewProtocol

extension StakingPayoutConfirmationViewController: StakingPayoutConfirmationViewProtocol {
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel

        applyFeeViewModel()
    }

    func didRecieve(amountViewModel: LocalizableResource<BalanceViewModelProtocol>) {
        self.amountViewModel = amountViewModel

        applyAmountViewModel()
    }

    func didRecieve(viewModel: LocalizableResource<PayoutConfirmViewModel>) {
        self.viewModel = viewModel

        applyConfirmationViewModel()
    }
}
