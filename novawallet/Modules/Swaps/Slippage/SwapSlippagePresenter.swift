import Foundation
import Foundation_iOS
import BigInt

final class SwapSlippagePresenter {
    weak var view: SwapSlippageViewProtocol?
    let wireframe: SwapSlippageWireframeProtocol
    let percentFormatterLocalizable: LocalizableResource<NumberFormatter>
    let completionHandler: (BigRational) -> Void
    let chainAsset: ChainAsset

    let initSlippage: Decimal?
    let defaultSlippage: Decimal
    let slippageTips: [Decimal]
    let bounds: SlippageBounds

    private var amountInput: Decimal?

    init(
        wireframe: SwapSlippageWireframeProtocol,
        percentFormatterLocalizable: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        initSlippage: BigRational?,
        config: SlippageConfig,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        self.wireframe = wireframe
        self.percentFormatterLocalizable = percentFormatterLocalizable
        self.initSlippage = initSlippage?.decimalValue
        defaultSlippage = config.defaultSlippage.decimalOrZeroValue
        bounds = .init(config: config)
        slippageTips = config.slippageTips.map(\.decimalOrZeroValue)

        self.chainAsset = chainAsset
        self.completionHandler = completionHandler
        self.localizationManager = localizationManager
    }

    private func provideTips() {
        let formatter = percentFormatterLocalizable.value(for: selectedLocale)

        let tips = slippageTips.map {
            SlippagePercentViewModel(
                value: $0,
                title: formatter.stringFromDecimal($0) ?? ""
            )
        }

        view?.didReceivePreFilledPercents(viewModel: tips)
    }

    private func percentToString(from decimal: Decimal) -> String {
        percentFormatterLocalizable
            .value(for: selectedLocale)
            .stringFromDecimal(decimal) ?? ""
    }

    private func provideAmountViewModel() {
        let inputViewModel = AmountInputViewModel.forAssetConversionSlippage(
            for: amountInput?.fromFractionToPercents(),
            locale: selectedLocale
        )

        view?.didReceiveInput(viewModel: inputViewModel)
    }

    private func provideButtonStates() {
        let error = bounds.error(
            for: amountInput,
            stringAmountClosure: percentToString,
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
            stringAmountClosure: percentToString,
            locale: selectedLocale
        )
        view?.didReceiveInput(error: error)
        provideButtonStates()
    }

    private func provideWarnings() {
        let warning = bounds.warning(for: amountInput, locale: selectedLocale)
        view?.didReceiveInput(warning: warning)
    }

    private func updateView() {
        provideAmountViewModel()
        provideButtonStates()
        provideWarnings()
        provideErrors()
        provideTips()
    }
}

extension SwapSlippagePresenter: SwapSlippagePresenterProtocol {
    func setup() {
        amountInput = initSlippage
        updateView()
    }

    func select(percent: SlippagePercentViewModel) {
        amountInput = percent.value
        provideAmountViewModel()
        provideButtonStates()
        provideErrors()
        provideWarnings()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount?.fromPercentsToFraction()
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
           let rational = BigRational.fraction(from: amountInput) {
            completionHandler(rational)
            wireframe.close(from: view)
        }
    }
}

extension SwapSlippagePresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
