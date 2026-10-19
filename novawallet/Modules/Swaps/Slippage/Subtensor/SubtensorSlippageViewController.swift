import UIKit
import Foundation_iOS

final class SubtensorSlippageViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSlippageViewLayout

    let presenter: SwapSlippagePresenterProtocol

    private var hasInputError: Bool = false
    private var isApplyAvailable: Bool = false
    private var presets: [SlippagePercentViewModel] = []
    private var inputViewModel: AmountInputViewModelProtocol?

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
        view = SubtensorSlippageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        setupAccessoryView()
        presenter.setup()
    }
}

private extension SubtensorSlippageViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.bind(
            title: strings.commonButtonSettings(),
            explanation: strings.stakingSubtensorUiSlippageExplanation()
        )
        rootView.slippageTitleLabel.text = strings.stakingSubtensorInfoSlippageTitle()
        rootView.actionButton.imageWithTitleView?.title = strings.commonDone()
        rootView.amountInput.textField.attributedPlaceholder = NSAttributedString(
            string: strings.stakingSubtensorUiSlippageCustom(),
            attributes: [
                .foregroundColor: R.color.colorTextSecondary()!,
                .font: UIFont.regularSubheadline
            ]
        )

        updatePreferredHeight()
    }

    func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(applyButtonAction), for: .touchUpInside)
        rootView.amountInput.addTarget(self, action: #selector(inputEditingAction), for: .editingChanged)
        rootView.presetsControl.addTarget(self, action: #selector(presetAction), for: .valueChanged)
    }

    func setupAccessoryView() {
        let accessoryView = UIFactory.default.createDoneAccessoryView(
            target: self,
            selector: #selector(doneButtonAction),
            locale: selectedLocale
        )
        rootView.amountInput.textField.inputAccessoryView = accessoryView
    }

    func updateActionButton() {
        let hasPreset = rootView.presetsControl.selectedIndex != nil
        let inputValid = hasPreset || rootView.amountInput.inputViewModel?.isValid == true

        let isEnabled = isApplyAvailable && !hasInputError && inputValid
        rootView.actionButton.set(enabled: isEnabled, changeStyle: true)
    }

    func applyInput() {
        let percent = inputViewModel?.decimalAmount

        let presetIndex = percent.flatMap { value in
            presets.firstIndex { $0.value.fromFractionToPercents() == value }
        }

        rootView.presetsControl.select(index: presetIndex)

        if presetIndex != nil {
            let customViewModel = AmountInputViewModel.forAssetConversionSlippage(for: nil, locale: selectedLocale)
            rootView.amountInput.bind(inputViewModel: customViewModel)
        } else if let inputViewModel {
            rootView.amountInput.bind(inputViewModel: inputViewModel)
        }

        updateActionButton()
    }

    func updatePreferredHeight() {
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let height = rootView.preferredHeight(for: width)

        guard preferredContentSize.height != height else {
            return
        }

        preferredContentSize = CGSize(width: 0, height: height)

        guard
            view.window != nil,
            let presentationController,
            let containerView = presentationController.containerView else {
            return
        }

        UIView.animate(withDuration: 0.25) {
            self.view.frame = presentationController.frameOfPresentedViewInContainerView
            containerView.layoutIfNeeded()
        }
    }

    @objc func applyButtonAction() {
        presenter.apply()
    }

    @objc func doneButtonAction() {
        rootView.amountInput.endEditing(true)
    }

    @objc func inputEditingAction() {
        let amount = rootView.amountInput.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        inputViewModel = rootView.amountInput.inputViewModel
        rootView.presetsControl.select(index: nil)

        updateActionButton()
    }

    @objc func presetAction() {
        guard let index = rootView.presetsControl.selectedIndex, let preset = presets[safe: index] else {
            return
        }

        rootView.amountInput.endEditing(true)
        presenter.select(percent: preset)
    }
}

extension SubtensorSlippageViewController: SwapSlippageViewProtocol {
    func didReceivePreFilledPercents(viewModel: [SlippagePercentViewModel]) {
        presets = viewModel
        rootView.presetsControl.bind(titles: viewModel.map(\.title))
        applyInput()
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        inputViewModel = viewModel
        applyInput()
    }

    func didReceiveResetState(available _: Bool) {}

    func didReceiveButtonState(available: Bool) {
        isApplyAvailable = available
        updateActionButton()
    }

    func didReceiveInput(error: String?) {
        hasInputError = error != nil
        rootView.set(error: error)
        updateActionButton()
        updatePreferredHeight()
    }

    func didReceiveInput(warning: String?) {
        rootView.set(warning: warning)
        updatePreferredHeight()
    }
}

extension SubtensorSlippageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
