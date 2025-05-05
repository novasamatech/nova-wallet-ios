import UIKit
import Foundation_iOS

final class CollatorStakingSetupViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = CollatorStakingSetupViewLayout

    let presenter: CollatorStakingSetupPresenterProtocol
    let localizableTitle: LocalizableResource<String>

    private var collatorViewModel: AccountDetailsSelectionViewModel?

    init(
        presenter: CollatorStakingSetupPresenterProtocol,
        localizableTitle: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizableTitle = localizableTitle

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CollatorStakingSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        updateActionButtonState()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = localizableTitle.value(for: selectedLocale)

        setupAmountInputAccessoryView()

        rootView.collatorTitleLabel.text = R.string.localizable.parachainStakingCollator(
            preferredLanguages: languages
        )

        applyCollator(viewModel: collatorViewModel)

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: languages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonAvailablePrefix(
            preferredLanguages: languages
        )

        rootView.rewardsView.titleLabel.text = R.string.localizable.stakingEstimatedEarnings(
            preferredLanguages: languages
        )

        rootView.minStakeView.titleLabel.text = R.string.localizable.stakingMainMinimumStakeTitle(
            preferredLanguages: languages
        )

        rootView.networkFeeView.locale = selectedLocale

        updateActionButtonState()
    }

    private func updateActionButtonState() {
        if collatorViewModel == nil {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .parachainStakingHintSelectCollator(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        if !rootView.amountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .transferSetupEnterAmount(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.actionButton.invalidateLayout()
    }

    private func applyAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    private func applyCollator(viewModel: AccountDetailsSelectionViewModel?) {
        if let viewModel = viewModel {
            rootView.collatorActionView.bind(viewModel: viewModel)
        } else {
            let emptyViewModel = AccountDetailsSelectionViewModel(
                displayAddress: DisplayAddressViewModel(
                    address: "",
                    name: R.string.localizable.parachainStakingSelectCollator(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    imageViewModel: nil
                ),
                details: nil
            )

            rootView.collatorActionView.bind(viewModel: emptyViewModel)
        }
    }

    private func applyRewards(viewModel: StakingRewardInfoViewModel) {
        rootView.rewardsView.priceLabel.text = viewModel.amountViewModel.price
        rootView.rewardsView.incomeLabel.text = viewModel.returnPercentage
        rootView.rewardsView.amountLabel.text = R.string.localizable.parachainStakingRewardsFormat(
            viewModel.amountViewModel.amount,
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.rewardsView.setNeedsLayout()
    }

    private func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupHandlers() {
        rootView.collatorActionView.addTarget(
            self,
            action: #selector(actionSelectCollator),
            for: .touchUpInside
        )

        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        updateActionButtonState()
    }

    @objc func actionSelectCollator() {
        presenter.selectCollator()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }
}

extension CollatorStakingSetupViewController: CollatorStakingSetupViewProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?) {
        collatorViewModel = viewModel

        applyCollator(viewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        applyAssetBalance(viewModel: viewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButtonState()
    }

    func didReceiveMinStake(viewModel: BalanceViewModelProtocol?) {
        rootView.minStakeView.bind(viewModel: viewModel)
    }

    func didReceiveReward(viewModel: StakingRewardInfoViewModel) {
        applyRewards(viewModel: viewModel)
    }
}

extension CollatorStakingSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension CollatorStakingSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
