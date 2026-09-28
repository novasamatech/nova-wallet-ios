import Foundation_iOS
import UIKit

final class SubtensorStakingSetupViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = SubtensorStakingSetupViewLayout

    let presenter: SubtensorStakingSetupPresenterProtocol
    let localizableTitle: LocalizableResource<String>
    let statics: CollatorStakingDelegateStatics

    private var collatorViewModel: AccountDetailsSelectionViewModel?
    private var isTargetLoading = false

    init(
        presenter: SubtensorStakingSetupPresenterProtocol,
        localizableTitle: LocalizableResource<String>,
        statics: CollatorStakingDelegateStatics,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizableTitle = localizableTitle
        self.statics = statics

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakingSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.setQuotePanel(hidden: true)
        rootView.rewardsView.isHidden = true
        rootView.receiveCell.isHidden = true
        rootView.poolFeeCell.isHidden = true
        rootView.priceImpactCell.isHidden = true
        rootView.slippageCell.isHidden = true

        setupLocalization()
        setupHandlers()

        updateActionButtonState()

        presenter.setup()
    }
}

private extension SubtensorStakingSetupViewController {
    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        let strings = R.string(preferredLanguages: languages).localizable

        title = localizableTitle.value(for: selectedLocale)

        setupAmountInputAccessoryView()

        rootView.networkTitleLabel.text = strings.stakingSubtensorUiYourSubnet()
        rootView.networkCell.titleLabel.text = strings.stakingSubtensorNetworkTitle()

        rootView.collatorTitleLabel.text = statics.delegateTitle.value(for: selectedLocale)

        applyCollator(viewModel: collatorViewModel)

        rootView.amountView.titleView.text = strings.stakingSubtensorUiYouStake()
        rootView.safetyNoteLabel.text = strings.stakingSubtensorUiSafetyNote()
        rootView.amountView.detailsTitleLabel.text = strings.commonAvailablePrefix()

        rootView.receiveCell.titleLabel.text = strings.stakingSubtensorQuoteReceiveTitle()
        rootView.poolFeeCell.titleLabel.text = strings.stakingSubtensorQuotePoolFeeTitle()
        rootView.priceImpactCell.titleLabel.text = strings.stakingSubtensorQuotePriceImpactTitle()
        rootView.slippageCell.titleLabel.text = strings.swapsSetupSlippage()

        rootView.rewardsView.titleLabel.text = strings.stakingEstimatedEarnings()

        rootView.minStakeView.titleLabel.text = strings.stakingMainMinimumStakeTitle()

        rootView.networkFeeView.locale = selectedLocale

        updateActionButtonState()
    }

    func updateActionButtonState() {
        if isTargetLoading {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiLoadingSubnet()
            rootView.actionButton.invalidateLayout()
            return
        }
        if collatorViewModel == nil {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = statics.selectDelegateHint.value(
                for: selectedLocale
            )
            rootView.actionButton.invalidateLayout()

            return
        }

        if !rootView.amountInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.transferSetupEnterAmount()
            rootView.actionButton.invalidateLayout()

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
        rootView.actionButton.invalidateLayout()
    }

    func applyAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    func applyRewards(viewModel: StakingRewardInfoViewModel) {
        rootView.rewardsView.priceLabel.text = viewModel.amountViewModel.price
        rootView.rewardsView.incomeLabel.text = viewModel.returnPercentage
        rootView.rewardsView.amountLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.parachainStakingRewardsFormat(viewModel.amountViewModel.amount)

        rootView.rewardsView.setNeedsLayout()
    }

    func applyCollator(viewModel: AccountDetailsSelectionViewModel?) {
        if let viewModel {
            rootView.collatorActionView.bind(viewModel: viewModel)
        } else {
            let emptyViewModel = AccountDetailsSelectionViewModel(
                displayAddress: DisplayAddressViewModel(
                    address: "",
                    name: statics.selectDelegateTitle.value(for: selectedLocale),
                    imageViewModel: nil
                ),
                details: nil
            )

            rootView.collatorActionView.bind(viewModel: emptyViewModel)
        }
    }

    func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    func setupHandlers() {
        rootView.networkCell.addTarget(
            self,
            action: #selector(actionSelectNetwork),
            for: .touchUpInside
        )

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

        rootView.slippageCell.addTarget(
            self,
            action: #selector(actionSelectSlippage),
            for: .touchUpInside
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

    @objc func actionSelectNetwork() {
        presenter.selectStakeTarget()
    }

    @objc func actionSelectCollator() {
        presenter.selectCollator()
    }

    @objc func actionSelectSlippage() {
        presenter.selectSlippage()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }
}

extension SubtensorStakingSetupViewController: SubtensorStakingSetupViewProtocol {
    func didReceiveTargetLoading(_ isLoading: Bool) {
        isTargetLoading = isLoading
        rootView.targetLoadingView.setLoading(isLoading)
        rootView.networkTitleLabel.isHidden = isLoading
        rootView.networkTableView.isHidden = isLoading
        rootView.collatorTitleLabel.isHidden = isLoading
        rootView.collatorTableView.isHidden = isLoading
        updateActionButtonState()
    }

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

    func didReceiveRewardHidden(_ isHidden: Bool) {
        rootView.rewardsView.isHidden = isHidden
    }

    func didReceiveStakeTarget(viewModel: SubtensorStakeTargetViewModel) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        title = viewModel.isRoot ? strings.stakingSubtensorUiStakeToRoot() : strings.stakingSubtensorUiEarnWith()
        rootView.networkTitleLabel.text = viewModel.isRoot
            ? strings.stakingSubtensorUiStakingMethod() : strings.stakingSubtensorUiYourSubnet()
        rootView.networkCell.bind(details: viewModel.title)
    }

    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?) {
        let hasQuote = viewModel != nil

        rootView.receiveCell.isHidden = !hasQuote
        rootView.poolFeeCell.isHidden = !hasQuote
        rootView.priceImpactCell.isHidden = !hasQuote

        updateQuotePanelVisibility()

        guard let viewModel else {
            return
        }

        rootView.receiveCell.bind(details: viewModel.receive)
        rootView.poolFeeCell.bind(details: viewModel.poolFee)
        rootView.priceImpactCell.bind(details: viewModel.priceImpact)

        rootView.priceImpactCell.detailsLabel.textColor = viewModel.isImpactHigh
            ? R.color.colorTextNegative()
            : R.color.colorTextPrimary()
    }

    func didReceiveSlippage(viewModel: String?) {
        rootView.slippageCell.isHidden = viewModel == nil
        rootView.slippageCell.bind(details: viewModel ?? "")

        updateQuotePanelVisibility()
    }
}

private extension SubtensorStakingSetupViewController {
    func updateQuotePanelVisibility() {
        rootView.setQuotePanel(
            hidden: rootView.receiveCell.isHidden && rootView.slippageCell.isHidden
        )
    }
}

extension SubtensorStakingSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorStakingSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
