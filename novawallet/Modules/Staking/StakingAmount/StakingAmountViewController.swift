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

        presenter.setup()
    }

    // MARK: Private

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: locale)
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        title = R.string.localizable.stakingStake(preferredLanguages: languages)

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: languages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: languages
        )

        rootView.restakeOptionView.title = R.string.localizable.stakingSetupRestakeTitle_v2_2_0(
            preferredLanguages: languages
        )

        rootView.payoutOptionView.title = R.string.localizable.stakingSetupPayoutTitle(
            preferredLanguages: languages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        rootView.networkFeeView.locale = locale

        applyAsset()
        applyFee()
        applyRewardDestinationViewModel()

        rootView.accountView.title = R.string.localizable.stakingRewardPayoutAccount(
            preferredLanguages: languages
        )

        setupBalanceAccessoryView()
    }

    private func updateActionButton() {
        let isEnabled = (amountInputViewModel?.isValid == true)

        if isEnabled {
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.isUserInteractionEnabled = true
        } else {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false
        }
    }

    private func applyAsset() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = assetViewModel?.value(for: locale) {
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

        let restakeColor = restakeView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!
        let payoutColor = payoutView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!

        if let reward = viewModel.rewardViewModel {
            restakeView.amountTitle = reward.restakeAmount
            restakeView.incomeTitle = reward.restakePercentage
            restakeView.priceTitle = reward.restakePrice
            payoutView.amountTitle = reward.payoutAmount
            payoutView.incomeTitle = reward.payoutPercentage
            payoutView.priceTitle = reward.payoutPrice
        } else {
            restakeView.amountTitle = ""
            restakeView.priceTitle = ""
            restakeView.incomeTitle = ""
            payoutView.amountTitle = ""
            payoutView.priceTitle = ""
            payoutView.incomeTitle = ""
        }

        restakeView.titleLabel.textColor = restakeColor
        restakeView.amountLabel.textColor = restakeColor
        payoutView.titleLabel.textColor = payoutColor
        payoutView.amountLabel.textColor = payoutColor

        restakeView.setNeedsLayout()
        payoutView.setNeedsLayout()
    }

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        let restakeView = rootView.restakeOptionView
        let payoutView = rootView.payoutOptionView

        switch viewModel.type {
        case .restake:
            restakeView.isSelected = true
            payoutView.isSelected = false

            rootView.accountView.isHidden = true
        case let .payout(icon, title):
            restakeView.isSelected = false
            payoutView.isSelected = true

            rootView.accountView.isHidden = false
            applyPayoutAddress(icon, title: title)
        }
    }

    private func applyPayoutAddress(_ icon: DrawableIcon, title: String) {
        let icon = icon.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        let accountView = rootView.accountView
        accountView.iconImage = icon
        accountView.subtitle = title
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
        rootView.amountInputView.textField.text = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingAmountViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
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
