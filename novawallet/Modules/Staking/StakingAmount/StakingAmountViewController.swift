import UIKit
import SoraFoundation
import SoraUI
import SubstrateSdk
import CommonWallet

final class StakingAmountViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingAmountLayout

    let presenter: StakingAmountPresenterProtocol

    private var rewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var amountInputViewModel: AmountInputViewModelProtocol?

    init(presenter: StakingAmountPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingAmountLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBalanceAccessoryView()
        setupLocalization()
        updateActionButton()
        updateRewardDestination()
        setupHandlers()

        presenter.setup()
    }

    // MARK: Private

    private func setupHandlers() {
        rootView.restakeOptionView.addTarget(self, action: #selector(actionRestake), for: .touchUpInside)
        rootView.payoutOptionView.addTarget(self, action: #selector(actionPayout), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
        rootView.aboutLinkView.actionButton.addTarget(self, action: #selector(actionLearnPayout), for: .touchUpInside)

        let accountControl = rootView.accountView.actionControl
        accountControl.addTarget(self, action: #selector(actionSelectPayoutAccount), for: .valueChanged)
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: languages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: languages
        )

        rootView.aboutLinkView.titleView.text = R.string.localizable.stakingRewardsDestinationTitle(
            preferredLanguages: languages
        )

        rootView.aboutLinkView.actionButton.imageWithTitleView?.title = R.string.localizable.stakingAboutRewards(
            preferredLanguages: languages
        )

        rootView.restakeOptionView.titleLabel.text = R.string.localizable.stakingSetupRestakeTitle_v2_2_0(
            preferredLanguages: languages
        )

        rootView.payoutOptionView.titleLabel.text = R.string.localizable.stakingSetupPayoutTitle(
            preferredLanguages: languages
        )

        rootView.networkFeeView.locale = locale

        applyAsset()
        applyFee()
        applyRewardDestinationViewModel()

        rootView.accountView.titleLabel.text = R.string.localizable.stakingRewardPayoutAccount(
            preferredLanguages: languages
        )

        setupBalanceAccessoryView()

        updateActionButton()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)

        if isEnabled {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.isUserInteractionEnabled = true
        } else {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonInputAmountHint(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.actionButton.applyTranslucentDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false
        }
    }

    private func updateRewardDestination() {
        let hasAmount = !(amountInputViewModel?.displayAmount ?? "").isEmpty

        let textColor: UIColor?

        if hasAmount {
            textColor = R.color.colorWhite()
        } else {
            textColor = R.color.colorTransparentText()
        }

        rootView.restakeOptionView.amountLabel.textColor = textColor
        rootView.payoutOptionView.amountLabel.textColor = textColor
    }

    private func applyAsset() {
        if let viewModel = assetViewModel?.value(for: selectedLocale) {
            title = R.string.localizable.stakingStakeFormat(
                viewModel.symbol,
                preferredLanguages: selectedLocale.rLanguages
            )

            let assetViewModel = AssetViewModel(
                symbol: viewModel.symbol,
                imageViewModel: viewModel.iconViewModel
            )

            rootView.amountInputView.bind(assetViewModel: assetViewModel)
            rootView.amountInputView.bind(priceViewModel: viewModel.price)

            rootView.amountView.detailsValueLabel.text = viewModel.balance
        }
    }

    private func applyFee() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let fee = feeViewModel?.value(for: locale)
        rootView.networkFeeView.bind(viewModel: fee)
    }

    private func applyRewardDestinationViewModel() {
        guard let rewardDestViewModel = rewardDestinationViewModel else { return }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let viewModel = rewardDestViewModel.value(for: locale)
        applyRewardDestinationType(from: viewModel)
        applyRewardDestinationContent(from: viewModel)
    }

    private func applyRewardDestinationContent(from viewModel: RewardDestinationViewModelProtocol) {
        let restakeView = rootView.restakeOptionView
        let payoutView = rootView.payoutOptionView

        if let reward = viewModel.rewardViewModel {
            restakeView.amountLabel.text = reward.restakeAmount
            restakeView.incomeLabel.text = reward.restakePercentage
            restakeView.priceLabel.text = reward.restakePrice
            payoutView.amountLabel.text = reward.payoutAmount
            payoutView.incomeLabel.text = reward.payoutPercentage
            payoutView.priceLabel.text = reward.payoutPrice
        } else {
            restakeView.amountLabel.text = ""
            restakeView.incomeLabel.text = ""
            restakeView.priceLabel.text = ""
            payoutView.amountLabel.text = ""
            payoutView.incomeLabel.text = ""
            payoutView.priceLabel.text = ""
        }

        restakeView.setNeedsLayout()
        payoutView.setNeedsLayout()
    }

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        let restakeView = rootView.restakeOptionView
        let payoutView = rootView.payoutOptionView
        let accountView = rootView.accountView

        switch viewModel.type {
        case .restake:
            restakeView.isSelected = true
            payoutView.isSelected = false

            rootView.setAccountShown(false)
        case let .payout(details):
            restakeView.isSelected = false
            payoutView.isSelected = true

            rootView.setAccountShown(true)
            accountView.bind(viewModel: details)
        }
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

    @objc private func actionLearnPayout() {
        presenter.selectLearnMore()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionSelectPayoutAccount() {
        presenter.selectPayoutAccount()
    }
}

extension StakingAmountViewController: StakingAmountViewProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let concreteViewModel = viewModel.value(for: locale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        rootView.amountInputView.bind(inputViewModel: concreteViewModel)
        concreteViewModel.observable.add(observer: self)

        updateActionButton()
        updateRewardDestination()
    }

    func didCompletionAccountSelection() {
        rootView.accountView.actionControl.deactivate(animated: true)
    }
}

extension StakingAmountViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingAmountViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        updateActionButton()
        updateRewardDestination()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingAmountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
