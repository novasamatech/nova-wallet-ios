import UIKit
import SoraFoundation

final class StakingSetupAmountViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingSetupAmountViewLayout

    let presenter: StakingSetupAmountPresenterProtocol

    let keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol

    init(
        presenter: StakingSetupAmountPresenterProtocol,
        keyboardAppearanceStrategy: KeyboardAppearanceStrategyProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.keyboardAppearanceStrategy = keyboardAppearanceStrategy

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingSetupAmountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupAmountInputAccessoryView(for: selectedLocale)

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardAppearanceStrategy.onViewWillAppear(for: rootView.amountInputView.textField)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        keyboardAppearanceStrategy.onViewDidAppear(for: rootView.amountInputView.textField)
    }

    private func setupHandlers() {
        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )

        rootView.stakingTypeView.addTarget(
            self,
            action: #selector(selectStakingTypeAction),
            for: .touchUpInside
        )
    }

    @objc private func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)
    }

    @objc private func actionContinue() {
        presenter.proceed()
    }

    @objc private func selectStakingTypeAction() {
        presenter.selectStakingType()
    }

    private func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }
}

extension StakingSetupAmountViewController: StakingSetupAmountViewProtocol {
    func didReceive(estimatedRewards: LoadableViewModelState<TitleHorizontalMultiValueView.Model>?) {
        rootView.setEstimatedRewards(viewModel: estimatedRewards)
    }

    func didReceive(balance: TitleHorizontalMultiValueView.Model) {
        rootView.amountView.bind(balance: balance)
    }

    func didReceive(title: String) {
        self.title = title
    }

    func didReceiveButtonState(title: String, enabled: Bool) {
        rootView.actionButton.applyState(title: title, enabled: enabled)
    }

    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel) {
        rootView.amountInputView.bind(assetViewModel: viewModel.assetViewModel)
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(viewModel: String?) {
        rootView.amountInputView.bind(priceViewModel: viewModel)
    }

    func didReceive(stakingType: LoadableViewModelState<StakingTypeViewModel>?) {
        rootView.setStakingType(viewModel: stakingType)
    }
}

extension StakingSetupAmountViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension StakingSetupAmountViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }
        setupAmountInputAccessoryView(for: selectedLocale)
    }
}
