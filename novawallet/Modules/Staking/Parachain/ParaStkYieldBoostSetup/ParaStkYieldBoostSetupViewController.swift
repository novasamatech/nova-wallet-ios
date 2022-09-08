import UIKit
import CommonWallet
import SoraFoundation

final class ParaStkYieldBoostSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkYieldBoostSetupViewLayout

    let presenter: ParaStkYieldBoostSetupPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private var collatorViewModel: AccountDetailsSelectionViewModel?
    private var yieldBoostPeriod: ParaStkYieldBoostPeriodViewModel?
    private var hasChanges: Bool = false

    init(presenter: ParaStkYieldBoostSetupPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkYieldBoostSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonYieldBoost(preferredLanguages: languages)

        rootView.collatorTitleLabel.text = R.string.localizable.yieldBoostSetupCollatorTitle(
            preferredLanguages: languages
        )

        applyCollator(viewModel: collatorViewModel)

        rootView.rewardComparisonTitleLabel.text = R.string.localizable.yieldBoostSetupRewardComparisonTitle(
            preferredLanguages: languages
        )

        rootView.withoutYieldBoostOptionView.titleLabel.text = R.string.localizable.withoutYieldBoost(
            preferredLanguages: languages
        )

        rootView.withYieldBoostOptionView.titleLabel.text = R.string.localizable.withYieldBoost(
            preferredLanguages: languages
        )

        applyYieldBoostPeriod(viewModel: yieldBoostPeriod)

        rootView.amountView.titleView.text = R.string.localizable.yieldBoostThreshold(preferredLanguages: languages)
        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: languages
        )

        setupThresholdAmountInputAccessoryView()

        updateActionButtonState()
    }

    private func setupThresholdAmountInputAccessoryView() {
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

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )

        rootView.withoutYieldBoostOptionView.addTarget(
            self,
            action: #selector(actionWithoutYiedBoostSelected),
            for: .touchUpInside
        )

        rootView.withYieldBoostOptionView.addTarget(
            self,
            action: #selector(actionWithYiedBoostSelected),
            for: .touchUpInside
        )

        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )
    }

    private func applyYieldBoostPeriod(viewModel: ParaStkYieldBoostPeriodViewModel?) {
        let period: String

        if let newDays = viewModel?.new {
            let newDaysString = R.string.localizable.commonDaysFormat(
                format: Int(bitPattern: newDays),
                preferredLanguages: selectedLocale.rLanguages
            )

            let updating: String

            if let oldDays = viewModel?.old, oldDays != newDays {
                let oldDaysString = R.string.localizable.commonDaysFormat(
                    format: Int(bitPattern: oldDays),
                    preferredLanguages: selectedLocale.rLanguages
                )

                updating = R.string.localizable.yieldBoostSetupPeriodUpdate(
                    oldDaysString,
                    preferredLanguages: selectedLocale.rLanguages
                )
            } else {
                updating = ""
            }

            period = newDaysString + " " + updating

        } else {
            period = "⌛"
        }

        rootView.thresholdDetailsLabel.text = R.string.localizable.yieldBoostSetupPeriodDetails(
            period,
            preferredLanguages: selectedLocale.rLanguages
        )
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

    private func applyRewardOption(
        to rewardView: RewardSelectionView,
        viewModel: ParaStkYieldBoostComparisonViewModel.Reward?
    ) {
        rewardView.incomeLabel.text = viewModel?.percent
        rewardView.amountLabel.text = viewModel?.balance.amount
        rewardView.priceLabel.text = viewModel?.balance.price

        rewardView.setNeedsLayout()
    }

    private func updateActionButtonState() {
        if collatorViewModel == nil {
            let title = R.string.localizable.parachainStakingHintSelectCollator(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.actionButton.applyState(title: title, enabled: false)

            return
        }

        if !rootView.amountInputView.completed {
            let title = R.string.localizable.transferSetupEnterAmount(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.applyState(title: title, enabled: false)

            return
        }

        if !hasChanges {
            let title = R.string.localizable.commonNoChanges(preferredLanguages: selectedLocale.rLanguages)
            rootView.actionButton.applyState(title: title, enabled: false)

            return
        }

        let title = R.string.localizable.commonContinue(preferredLanguages: selectedLocale.rLanguages)

        rootView.actionButton.applyState(title: title, enabled: true)
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionWithoutYiedBoostSelected() {
        guard !rootView.withoutYieldBoostOptionView.isChoosen else {
            return
        }

        presenter.switchRewardsOption(to: false)
    }

    @objc private func actionWithYiedBoostSelected() {
        guard !rootView.withYieldBoostOptionView.isChoosen else {
            return
        }

        presenter.switchRewardsOption(to: true)
    }

    @objc private func actionSelectCollator() {
        presenter.selectCollator()
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateThresholdAmount(amount)

        updateActionButtonState()
    }
}

extension ParaStkYieldBoostSetupViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let responderView = rootView.amountInputView

            let fieldFrame = scrollView.convert(
                responderView.frame,
                from: responderView.superview
            )

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}

extension ParaStkYieldBoostSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectThresholdAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension ParaStkYieldBoostSetupViewController: ParaStkYieldBoostSetupViewProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?) {
        collatorViewModel = viewModel

        applyCollator(viewModel: viewModel)

        updateActionButtonState()
    }

    func didReceiveRewardComparison(viewModel: ParaStkYieldBoostComparisonViewModel) {
        applyRewardOption(to: rootView.withoutYieldBoostOptionView, viewModel: viewModel.apr)
        applyRewardOption(to: rootView.withYieldBoostOptionView, viewModel: viewModel.apy)
    }

    func didReceiveYieldBoostSelected(_ isYieldBoosted: Bool) {
        rootView.withoutYieldBoostOptionView.isChoosen = !isYieldBoosted
        rootView.withYieldBoostOptionView.isChoosen = isYieldBoosted

        rootView.thresholdDetailsLabel.isHidden = !isYieldBoosted
        rootView.amountView.isHidden = !isYieldBoosted
        rootView.amountInputView.isHidden = !isYieldBoosted
        rootView.poweredByView.isHidden = !isYieldBoosted
    }

    func didReceiveYieldBoostPeriod(viewModel: ParaStkYieldBoostPeriodViewModel?) {
        yieldBoostPeriod = viewModel

        applyYieldBoostPeriod(viewModel: viewModel)
    }

    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButtonState()
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }

    func didReceiveHasChanges(viewModel: Bool) {
        hasChanges = viewModel

        updateActionButtonState()
    }
}

extension ParaStkYieldBoostSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
