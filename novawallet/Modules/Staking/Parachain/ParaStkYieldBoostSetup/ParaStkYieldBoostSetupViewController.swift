import UIKit
import CommonWallet
import SoraFoundation

final class ParaStkYieldBoostSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkYieldBoostSetupViewLayout

    let presenter: ParaStkYieldBoostSetupPresenterProtocol

    private var collatorViewModel: AccountDetailsSelectionViewModel?
    private var yieldBoostPeriod: UInt?

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

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

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

        applyYieldBoostPeriod(days: yieldBoostPeriod)

        rootView.amountView.titleView.text = R.string.localizable.yieldBoostThreshold(preferredLanguages: languages)
        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: languages
        )

        updateActionButtonState()
    }

    private func applyYieldBoostPeriod(days: UInt?) {
        let period: String

        if let days = days {
            period = R.string.localizable.commonDaysFormat(
                format: Int(bitPattern: days),
                preferredLanguages: selectedLocale.rLanguages
            )
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

    func didReceiveYieldBoostPeriod(days: UInt?) {
        yieldBoostPeriod = days

        applyYieldBoostPeriod(days: days)
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
}

extension ParaStkYieldBoostSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
