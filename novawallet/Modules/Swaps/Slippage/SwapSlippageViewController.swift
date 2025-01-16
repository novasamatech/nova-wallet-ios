import UIKit
import Foundation_iOS

final class SwapSlippageViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSlippageViewLayout

    let presenter: SwapSlippagePresenterProtocol
    private var isApplyAvailable: Bool = false

    init(
        presenter: SwapSlippagePresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapSlippageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        setupAccessoryView()
        setupNavigationItem()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable.swapsSetupSettingsTitle(
            preferredLanguages: languages)
        rootView.slippageButton.imageWithTitleView?.title = R.string.localizable.swapsSetupSlippage(
            preferredLanguages: languages)
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: languages)
        navigationItem.rightBarButtonItem?.title = R.string.localizable.commonReset(
            preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupHandlers() {
        rootView.amountInput.delegate = self
        rootView.actionButton.addTarget(self, action: #selector(applyButtonAction), for: .touchUpInside)
        rootView.amountInput.addTarget(self, action: #selector(inputEditingAction), for: .editingChanged)
        rootView.slippageButton.addTarget(self, action: #selector(slippageInfoAction), for: .touchUpInside)
    }

    private func setupAccessoryView() {
        let accessoryView =
            UIFactory.default.createDoneAccessoryView(
                target: self,
                selector: #selector(doneButtonAction),
                locale: selectedLocale
            )
        rootView.amountInput.textField.inputAccessoryView = accessoryView
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = .init(
            title: R.string.localizable.commonReset(preferredLanguages: selectedLocale.rLanguages),
            style: .plain,
            target: self,
            action: #selector(resetAction)
        )
    }

    private func updateActionButton() {
        let inputValid = rootView.amountInput.inputViewModel?.isValid == true

        let isEnabled = isApplyAvailable && inputValid
        rootView.actionButton.set(enabled: isEnabled, changeStyle: true)
    }

    @objc private func applyButtonAction() {
        presenter.apply()
    }

    @objc private func doneButtonAction() {
        rootView.amountInput.endEditing(true)
    }

    @objc private func inputEditingAction() {
        let amount = rootView.amountInput.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)
        updateActionButton()
    }

    @objc private func slippageInfoAction() {
        presenter.showSlippageInfo()
    }

    @objc private func resetAction() {
        presenter.reset()
    }
}

extension SwapSlippageViewController: SwapSlippageViewProtocol {
    func didReceivePreFilledPercents(viewModel: [SlippagePercentViewModel]) {
        rootView.amountInput.bind(viewModel: viewModel)
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        rootView.amountInput.bind(inputViewModel: viewModel)
        updateActionButton()
    }

    func didReceiveResetState(available: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = available
    }

    func didReceiveButtonState(available: Bool) {
        isApplyAvailable = available
        updateActionButton()
    }

    func didReceiveInput(error: String?) {
        rootView.set(error: error)
        updateActionButton()
    }

    func didReceiveInput(warning: String?) {
        rootView.set(warning: warning)
    }
}

extension SwapSlippageViewController: PercentInputViewDelegateProtocol {
    func didSelect(percent: SlippagePercentViewModel, sender _: Any?) {
        presenter.select(percent: percent)
        updateActionButton()
    }
}

extension SwapSlippageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
