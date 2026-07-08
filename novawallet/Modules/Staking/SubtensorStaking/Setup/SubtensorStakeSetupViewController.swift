import UIKit
import Foundation_iOS
import BigInt

/// Subtensor stake setup view controller. Binds the Nova layout
/// (`SubtensorStakeSetupViewLayout`) to the presenter, mirroring
/// `CollatorStakingSetupViewController`'s binding shape so the flow feels
/// consistent with parachain / Mythos staking.
///
/// Phase A scope:
///  - select validator via modal picker
///  - enter amount (Max button / accessory percentages wired)
///  - display live asset balance + price + min-stake + estimated fee
///
/// Phase B/C will replace `proceed()` with a real confirm / submit screen.
final class SubtensorStakeSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakeSetupViewLayout

    let presenter: SubtensorStakeSetupPresenterProtocol
    let subnetName: String?

    private var validatorViewModel: AccountDetailsSelectionViewModel?

    init(
        presenter: SubtensorStakeSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        subnetName: String? = nil
    ) {
        self.presenter = presenter
        self.subnetName = subnetName

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakeSetupViewLayout()
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

        if let subnetName {
            title = "Stake — SN\(presenter.netuid) \(subnetName)"
        } else {
            title = R.string(preferredLanguages: languages).localizable.stakingSubtensorTitle()
        }

        setupAmountInputAccessoryView()

        rootView.validatorTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.stakingSubtensorValidator()

        applyValidator(viewModel: validatorViewModel)

        rootView.amountView.titleView.text = R.string(
            preferredLanguages: languages
        ).localizable.walletSendAmountTitle()

        rootView.amountView.detailsTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.commonAvailablePrefix()

        rootView.minStakeView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.stakingMainMinimumStakeTitle()

        rootView.networkFeeView.locale = selectedLocale
        rootView.novaFeeView.locale = selectedLocale

        rootView.novaFeeDisclaimerLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.subtensorNovaFeeDisclaimer(SubtensorStakingConstants.novaFeePercentDisplay)

        updateActionButtonState()
    }

    private func updateActionButtonState() {
        if validatorViewModel == nil {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorHintSelectValidator()
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

    private func applyAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)

        rootView.amountView.detailsValueLabel.text = viewModel.balance
    }

    private func applyValidator(viewModel: AccountDetailsSelectionViewModel?) {
        if let viewModel = viewModel {
            rootView.validatorActionView.bind(viewModel: viewModel)
        } else {
            let emptyViewModel = AccountDetailsSelectionViewModel(
                displayAddress: DisplayAddressViewModel(
                    address: "",
                    name: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.stakingSubtensorSelectValidator(),
                    imageViewModel: nil
                ),
                details: nil
            )

            rootView.validatorActionView.bind(viewModel: emptyViewModel)
        }
    }

    private func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupHandlers() {
        rootView.validatorActionView.addTarget(
            self,
            action: #selector(actionSelectValidator),
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

    @objc private func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        updateActionButtonState()
    }

    @objc private func actionSelectValidator() {
        presenter.selectValidator()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }
}

extension SubtensorStakeSetupViewController: SubtensorStakeSetupViewProtocol {
    func didReceiveValidator(viewModel: AccountDetailsSelectionViewModel?) {
        validatorViewModel = viewModel

        applyValidator(viewModel: viewModel)

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

    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?) {
        // The presenter only calls this on a subnet with a fee address set, so
        // the row is always shown here. A nil view model means "amount not yet
        // entered" and surfaces the row's built-in loading spinner. Root /
        // no-address screens never call this, so the row stays hidden (its
        // layout default).
        rootView.novaFeeView.isHidden = false
        rootView.novaFeeView.bind(viewModel: viewModel)
    }

    func didReceiveNovaFeeDisclaimer(visible: Bool) {
        rootView.novaFeeDisclaimerLabel.isHidden = !visible
    }
}

extension SubtensorStakeSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorStakeSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
