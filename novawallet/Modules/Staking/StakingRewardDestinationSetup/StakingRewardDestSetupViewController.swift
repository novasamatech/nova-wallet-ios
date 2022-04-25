import UIKit
import CommonWallet
import SubstrateSdk
import SoraFoundation

final class StakingRewardDestSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDestSetupLayout

    let presenter: StakingRewardDestSetupPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var rewardDestinationViewModel: ChangeRewardDestinationViewModel?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    init(
        presenter: StakingRewardDestSetupPresenterProtocol,
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
        view = StakingRewardDestSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupView()

        presenter.setup()
    }

    // MARK: - Actions

    @objc private func actionLearnMore() {
        presenter.displayLearnMore()
    }

    @objc private func actionRestake() {
        if !rootView.restakeOptionView.isSelected {
            presenter.selectRestakeDestination()
        }
    }

    @objc private func actionPayout() {
        if !rootView.payoutOptionView.isSelected {
            presenter.selectPayoutDestination()
        }
    }

    @objc private func actionSelectPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    // MARK: - Private functions

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        switch viewModel.type {
        case .restake:
            rootView.restakeOptionView.isSelected = true
            rootView.payoutOptionView.isSelected = false

            rootView.setupPayoutAccountShown(false)

        case let .payout(details):

            rootView.restakeOptionView.isSelected = false
            rootView.payoutOptionView.isSelected = true

            rootView.setupPayoutAccountShown(true)

            rootView.accountView.bind(viewModel: details)
        }

        rootView.restakeOptionView.setNeedsLayout()
        rootView.payoutOptionView.setNeedsLayout()
    }

    private func applyRewardDestinationContent(from viewModel: RewardDestinationViewModelProtocol) {
        if let reward = viewModel.rewardViewModel {
            rootView.restakeOptionView.amountLabel.text = reward.restakeAmount
            rootView.restakeOptionView.priceLabel.text = reward.restakePrice
            rootView.restakeOptionView.incomeLabel.text = reward.restakePercentage
            rootView.payoutOptionView.amountLabel.text = reward.payoutAmount
            rootView.payoutOptionView.priceLabel.text = reward.payoutPrice
            rootView.payoutOptionView.incomeLabel.text = reward.payoutPercentage
        } else {
            rootView.restakeOptionView.amountLabel.text = ""
            rootView.restakeOptionView.priceLabel.text = ""
            rootView.restakeOptionView.incomeLabel.text = ""
            rootView.payoutOptionView.amountLabel.text = ""
            rootView.payoutOptionView.priceLabel.text = ""
            rootView.payoutOptionView.incomeLabel.text = ""
        }
    }

    // MARK: Data changes -

    private func applyRewardDestinationViewModel() {
        if let rewardDestViewModel = rewardDestinationViewModel {
            let viewModel = rewardDestViewModel.selectionViewModel.value(for: selectedLocale)
            applyRewardDestinationType(from: viewModel)
            applyRewardDestinationContent(from: viewModel)
        }

        let isEnabled = rewardDestinationViewModel?.canApply ?? false
        rootView.actionButton.set(enabled: isEnabled)
    }

    private func applyFee() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    // MARK: Setup -

    private func setupView() {
        rootView.learnMoreView.actionButton.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )

        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
        rootView.restakeOptionView.addTarget(self, action: #selector(actionRestake), for: .touchUpInside)
        rootView.payoutOptionView.addTarget(self, action: #selector(actionPayout), for: .touchUpInside)

        rootView.accountView.actionControl.addTarget(
            self,
            action: #selector(actionSelectPayoutAccount),
            for: .touchUpInside
        )

        rootView.restakeOptionView.isSelected = true
        rootView.payoutOptionView.isSelected = false
    }
}

extension StakingRewardDestSetupViewController: StakingRewardDestSetupViewProtocol {
    func didReceiveRewardDestination(viewModel: ChangeRewardDestinationViewModel?) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()
    }

    func didCompletionAccountSelection() {
        rootView.accountView.actionControl.deactivate(animated: true)
    }
}

extension StakingRewardDestSetupViewController: Localizable {
    private func setupLocalization() {
        title = R.string.localizable.stakingRewardsDestinationTitle_v2_0_0(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.locale = selectedLocale
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
