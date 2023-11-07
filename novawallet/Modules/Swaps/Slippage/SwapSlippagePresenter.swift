import Foundation
import SoraFoundation
import BigInt

final class SwapSlippagePresenter {
    weak var view: SwapSlippageViewProtocol?
    let wireframe: SwapSlippageWireframeProtocol
    let numberFormatterLocalizable: LocalizableResource<NumberFormatter>
    let percentFormatterLocalizable: LocalizableResource<NumberFormatter>
    let completionHandler: (BigRational) -> Void
    let chainAsset: ChainAsset

    let initSlippage: Decimal?
    let defaultSlippage: Decimal
    let slippageTips: [Decimal]
    let bounds: SlippageBounds

    private var percentFormatter: NumberFormatter
    private var numberFormatter: NumberFormatter
    private var amountInput: Decimal?

    init(
        wireframe: SwapSlippageWireframeProtocol,
        numberFormatterLocalizable: LocalizableResource<NumberFormatter>,
        percentFormatterLocalizable: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        initSlippage: BigRational?,
        config: SlippageConfig,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        self.wireframe = wireframe
        self.numberFormatterLocalizable = numberFormatterLocalizable
        self.percentFormatterLocalizable = percentFormatterLocalizable
        self.initSlippage = initSlippage?.decimalValue
        defaultSlippage = config.defaultSlippage.toPercents().decimalOrZeroValue
        bounds = .init(config: config)
        slippageTips = config.slippageTips.map { $0.toPercents().decimalOrZeroValue }

        self.chainAsset = chainAsset
        self.completionHandler = completionHandler
        percentFormatter = percentFormatterLocalizable.value(for: localizationManager.selectedLocale)
        numberFormatter = numberFormatterLocalizable.value(for: localizationManager.selectedLocale)
        self.localizationManager = localizationManager
    }

    private func title(for percent: Decimal) -> String {
        percentFormatter.stringFromDecimal(value(for: percent)) ?? ""
    }

    private func value(for percent: Decimal) -> Decimal {
        percent / (percentFormatter.multiplier?.decimalValue ?? 1)
    }

    private func provideAmountViewModel() {
        let inputViewModel = AmountInputViewModel(
            symbol: "",
            amount: amountInput,
            limit: 100,
            formatter: numberFormatter,
            precision: 4
        )

        view?.didReceiveInput(viewModel: inputViewModel)
    }

    private func provideButtonStates() {
        let error = bounds.error(
            for: amountInput,
            stringAmountClosure: title,
            locale: selectedLocale
        )

        let canReset = amountInput != defaultSlippage
        view?.didReceiveResetState(available: canReset)

        let canApply = amountInput != initSlippage && error == nil
        view?.didReceiveButtonState(available: canApply)
    }

    private func provideErrors() {
        let error = bounds.error(
            for: amountInput,
            stringAmountClosure: title,
            locale: selectedLocale
        )
        view?.didReceiveInput(error: error)
        provideButtonStates()
    }

    private func provideWarnings() {
        let warning = bounds.warning(for: amountInput, locale: selectedLocale)
        view?.didReceiveInput(warning: warning)
    }
}

extension SwapSlippagePresenter: SwapSlippagePresenterProtocol {
    func setup() {
        let viewModel = slippageTips.map {
            SlippagePercentViewModel(
                value: $0,
                title: title(for: $0)
            )
        }

        amountInput = initSlippage
        provideButtonStates()
        provideAmountViewModel()
        provideWarnings()
        view?.didReceivePreFilledPercents(viewModel: viewModel)
    }

    func select(percent: SlippagePercentViewModel) {
        amountInput = percent.value
        provideAmountViewModel()
        provideButtonStates()
        provideErrors()
        provideWarnings()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount
        provideButtonStates()
        provideErrors()
        provideWarnings()
    }

    func showSlippageInfo() {
        wireframe.showSlippageInfo(from: view)
    }

    func reset() {
        amountInput = defaultSlippage
        provideAmountViewModel()
        provideButtonStates()
        provideErrors()
        provideWarnings()
    }

    func apply() {
        if let amountInput = amountInput,
           let rational = BigRational.fraction(from: amountInput)?.fromPercents() {
            completionHandler(rational)
            wireframe.close(from: view)
        }
    }
}

extension SwapSlippagePresenter: Localizable {
    func applyLocalization() {
        percentFormatter = percentFormatterLocalizable.value(for: selectedLocale)
        numberFormatter = numberFormatterLocalizable.value(for: selectedLocale)
    }
}
