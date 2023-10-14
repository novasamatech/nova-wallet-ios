import UIKit
import SoraFoundation

final class SwapSlippageViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSlippageViewLayout

    let presenter: SwapSlippagePresenterProtocol

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
        presenter.setup()
    }

    private func setupLocalization() {
        title = "Swap settings"
        rootView.slippageButton.imageWithTitleView?.title = "Slippage"
        rootView.actionButton.imageWithTitleView?.title = "Apply"
    }

    private func setupHandlers() {
        rootView.amountInput.delegate = self
        rootView.actionButton.addTarget(self, action: #selector(applyButtonAction), for: .touchUpInside)
        rootView.amountInput.textField.addTarget(self, action: #selector(inputEditingAction), for: .editingChanged)
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

    private func updateActionButton() {
        rootView.actionButton.isEnabled = rootView.amountInput.inputViewModel?.isValid == true
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
}

extension SwapSlippageViewController: SwapSlippageViewProtocol {
    func didReceivePreFilledPercents(viewModel: [Percent]) {
        rootView.amountInput.bind(viewModel: viewModel)
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        rootView.amountInput.bind(inputViewModel: viewModel)
        updateActionButton()
    }
}

extension SwapSlippageViewController: SwapSlippageInputViewDelegateProtocol {
    func didSelect(percent: Percent, sender _: Any?) {
        presenter.select(percent: percent)
    }
}

extension SwapSlippageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
