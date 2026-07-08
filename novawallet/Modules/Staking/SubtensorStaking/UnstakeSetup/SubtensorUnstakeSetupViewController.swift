import UIKit
import Foundation_iOS
import BigInt

final class SubtensorUnstakeSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorUnstakeSetupViewLayout

    let presenter: SubtensorUnstakeSetupPresenterProtocol
    let netuid: UInt16
    let subnetName: String?

    init(
        presenter: SubtensorUnstakeSetupPresenterProtocol,
        netuid: UInt16,
        subnetName: String?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.netuid = netuid
        self.subnetName = subnetName

        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorUnstakeSetupViewLayout()
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

        if netuid == SubtensorStakingConstants.rootNetuid {
            title = "Unstake"
        } else if let subnetName, !subnetName.isEmpty {
            title = "Unstake — SN\(netuid) \(subnetName)"
        } else {
            title = "Unstake — SN\(netuid)"
        }

        setupAmountInputAccessoryView()

        rootView.validatorTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.stakingSubtensorValidator()

        rootView.amountView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.walletSendAmountTitle()

        rootView.positionView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.stakingSubtensorYourStake()

        rootView.networkFeeView.locale = selectedLocale
        rootView.novaFeeView.locale = selectedLocale

        rootView.novaFeeDisclaimerLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.subtensorNovaFeeDisclaimer(SubtensorStakingConstants.novaFeePercentDisplay)
    }

    private func updateActionButtonState() {
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

    private func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )
        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupHandlers() {
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

        rootView.amountView.button.addTarget(
            self,
            action: #selector(actionUseMax),
            for: .touchUpInside
        )

        // Validator section is read-only on unstake — no tap target.
    }

    @objc private func actionUseMax() {
        presenter.selectAmountPercentage(1.0)
    }

    @objc private func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)
        updateActionButtonState()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    private func applyValidator(viewModel: AccountDetailsSelectionViewModel) {
        rootView.validatorActionView.bind(viewModel: viewModel)
    }
}

extension SubtensorUnstakeSetupViewController: SubtensorUnstakeSetupViewProtocol {
    func didReceiveValidator(viewModel: AccountDetailsSelectionViewModel) {
        applyValidator(viewModel: viewModel)
    }

    func didReceivePosition(viewModel: BalanceViewModelProtocol) {
        rootView.positionView.bind(viewModel: viewModel)
    }

    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol) {
        let assetViewModel = AssetViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.iconViewModel
        )
        rootView.amountInputView.bind(assetViewModel: assetViewModel)
        rootView.amountInputView.bind(priceViewModel: viewModel.price)
        let languages = selectedLocale.rLanguages
        rootView.amountView.bind(model: TitleHorizontalMultiValueView.Model(
            title: R.string(preferredLanguages: languages).localizable.walletSendAmountTitle(),
            subtitle: R.string(preferredLanguages: languages).localizable.swapsSetupAssetMax(),
            value: viewModel.balance ?? ""
        ))
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?) {
        // Presenter only calls this on a subnet with a fee address set, so the
        // row is always shown here; a nil view model surfaces the row's built-in
        // loading spinner. Root / no-address screens never call it, so the row
        // stays hidden (its layout default).
        rootView.novaFeeView.isHidden = false
        rootView.novaFeeView.bind(viewModel: viewModel)
    }

    func didReceiveNovaFeeDisclaimer(visible: Bool) {
        rootView.novaFeeDisclaimerLabel.isHidden = !visible
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)
        updateActionButtonState()
    }
}

extension SubtensorUnstakeSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()
        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorUnstakeSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
