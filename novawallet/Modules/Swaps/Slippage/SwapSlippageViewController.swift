import UIKit
import Foundation_iOS

final class SwapSlippageViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSlippageViewLayout

    let presenter: SwapSlippagePresenterProtocol
    let presentation: SwapSlippagePresentation
    private var isApplyAvailable: Bool = false
    private var hasInputError: Bool = false
    private var presets: [SlippagePercentViewModel] = []
    private var sheetInputViewModel: AmountInputViewModelProtocol?

    init(
        presenter: SwapSlippagePresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        presentation: SwapSlippagePresentation = .screen
    ) {
        self.presenter = presenter
        self.presentation = presentation
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

        if presentation == .subtensorSheet {
            rootView.applySheetLayout()
        } else {
            setupNavigationItem()
        }

        setupLocalization()
        setupHandlers()
        setupAccessoryView()
        presenter.setup()
    }

    private func setupLocalization() {
        guard presentation == .screen else {
            setupSheetLocalization()
            return
        }

        let languages = selectedLocale.rLanguages
        title = R.string(preferredLanguages: languages).localizable.swapsSetupSettingsTitle()
        rootView.slippageButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.swapsSetupSlippage()
        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonApply()
        navigationItem.rightBarButtonItem?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonReset()
    }

    private func setupSheetLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.titleLabel.text = strings.commonButtonSettings()
        rootView.slippageButton.imageWithTitleView?.title = strings.stakingSubtensorInfoSlippageTitle()
        rootView.explanationLabel.text = strings.stakingSubtensorUiSlippageExplanation()
        rootView.actionButton.imageWithTitleView?.title = strings.commonDone()
        rootView.amountInput.textField.attributedPlaceholder = NSAttributedString(
            string: strings.stakingSubtensorUiSlippageCustom(),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )
    }

    private func setupHandlers() {
        rootView.amountInput.delegate = self
        rootView.actionButton.addTarget(self, action: #selector(applyButtonAction), for: .touchUpInside)
        rootView.amountInput.addTarget(self, action: #selector(inputEditingAction), for: .editingChanged)
        if presentation == .screen {
            rootView.slippageButton.addTarget(self, action: #selector(slippageInfoAction), for: .touchUpInside)
        } else {
            rootView.presetsControl.addTarget(self, action: #selector(presetAction), for: .valueChanged)
        }
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
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonReset(),
            style: .plain,
            target: self,
            action: #selector(resetAction)
        )
    }

    private func updateActionButton() {
        let hasPreset = presentation == .subtensorSheet && rootView.presetsControl.selectedIndex != nil
        let inputValid = hasPreset || rootView.amountInput.inputViewModel?.isValid == true
        let canApply = presentation == .screen ? isApplyAvailable : !hasInputError

        let isEnabled = canApply && inputValid
        rootView.actionButton.set(enabled: isEnabled, changeStyle: true)
    }

    @objc private func applyButtonAction() {
        presenter.apply()
    }

    @objc private func doneButtonAction() {
        rootView.amountInput.endEditing(true)
    }

    private func applySheetInput() {
        let percent = sheetInputViewModel?.decimalAmount

        let presetIndex = percent.flatMap { value in
            presets.firstIndex { $0.value.fromFractionToPercents() == value }
        }

        rootView.presetsControl.select(index: presetIndex)

        if presetIndex != nil {
            let customViewModel = AmountInputViewModel.forAssetConversionSlippage(for: nil, locale: selectedLocale)
            rootView.amountInput.bind(inputViewModel: customViewModel)
        } else if let sheetInputViewModel {
            rootView.amountInput.bind(inputViewModel: sheetInputViewModel)
        }

        updateActionButton()
    }

    @objc private func inputEditingAction() {
        let amount = rootView.amountInput.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        if presentation == .subtensorSheet {
            sheetInputViewModel = rootView.amountInput.inputViewModel
            rootView.presetsControl.select(index: nil)
        }

        updateActionButton()
    }

    @objc private func presetAction() {
        guard let index = rootView.presetsControl.selectedIndex, let preset = presets[safe: index] else {
            return
        }

        rootView.amountInput.endEditing(true)
        presenter.select(percent: preset)
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
        guard presentation == .subtensorSheet else {
            rootView.amountInput.bind(viewModel: viewModel)
            return
        }

        presets = viewModel
        rootView.presetsControl.bind(titles: viewModel.map(\.title))
        applySheetInput()
    }

    func didReceiveInput(viewModel: AmountInputViewModelProtocol) {
        guard presentation == .subtensorSheet else {
            rootView.amountInput.bind(inputViewModel: viewModel)
            updateActionButton()
            return
        }

        sheetInputViewModel = viewModel
        applySheetInput()
    }

    func didReceiveResetState(available: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = available
    }

    func didReceiveButtonState(available: Bool) {
        isApplyAvailable = available
        updateActionButton()
    }

    func didReceiveInput(error: String?) {
        hasInputError = error != nil
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
