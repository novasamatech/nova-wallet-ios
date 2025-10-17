import UIKit
import Foundation_iOS

final class StakingSetupAmountViewController: UIViewController, ViewHolder, ImportantViewProtocol {
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

        setupLocalization()
        setupHandlers()

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

    private func setupLocalization() {
        setupAmountInputAccessoryView(for: selectedLocale)

        rootView.estimatedRewardsView.titleView.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingEstimatedEarnings()

        rootView.estimatedRewardsView.detailsValueLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonPerYear()
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
    func didReceive(balance: TitleHorizontalMultiValueView.Model) {
        rootView.amountView.bind(model: balance)
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

        rootView.stakingTypeView.addTarget(
            self,
            action: #selector(selectStakingTypeAction),
            for: .touchUpInside
        )
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
        if isViewLoaded {
            setupLocalization()
        }
    }
}
