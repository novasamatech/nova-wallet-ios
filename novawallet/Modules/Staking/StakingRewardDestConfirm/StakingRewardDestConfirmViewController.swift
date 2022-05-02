import UIKit
import SoraFoundation

final class StakingRewardDestConfirmViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = StakingRewardDestConfirmViewLayout

    let presenter: StakingRewardDestConfirmPresenterProtocol

    private var confirmationViewModel: StakingRewardDestConfirmViewModel?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    init(
        presenter: StakingRewardDestConfirmPresenterProtocol,
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
        view = StakingRewardDestConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.accountCell.addTarget(self, action: #selector(actionSenderAccount), for: .touchUpInside)
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingRewardsDestinationTitle_v2_0_0(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.locale = selectedLocale

        applyFeeViewModel()
        applyConfirmationViewModel()
    }

    private func applyFeeViewModel() {
        let feeViewModel = feeViewModel?.value(for: selectedLocale)
        rootView.bind(feeViewModel: feeViewModel)
    }

    private func applyConfirmationViewModel() {
        guard let viewModel = confirmationViewModel else {
            return
        }

        rootView.bind(confirmationViewModel: viewModel)

        if
            let payoutAccount = rootView.payoutAccountCell,
            payoutAccount.actions(forTarget: self, forControlEvent: .touchUpInside) == nil {
            payoutAccount.addTarget(self, action: #selector(actionPayoutAccount), for: .touchUpInside)
        }
    }

    @objc private func actionSenderAccount() {
        presenter.presentSenderAccountOptions()
    }

    @objc private func actionPayoutAccount() {
        presenter.presentPayoutAccountOptions()
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }
}

extension StakingRewardDestConfirmViewController: StakingRewardDestConfirmViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel) {
        confirmationViewModel = viewModel

        applyConfirmationViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel

        applyFeeViewModel()
    }
}

extension StakingRewardDestConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
