import Foundation
import SoraFoundation
import BigInt

final class SwapSlippagePresenter {
    weak var view: SwapSlippageViewProtocol?
    let wireframe: SwapSlippageWireframeProtocol
    let numberFormatterLocalizable: LocalizableResource<NumberFormatter>
    let percentFormatterLocalizable: LocalizableResource<NumberFormatter>
    let completionHandler: (BigRational) -> Void
    let prefilledPercents: [Decimal] = [0.1, 1, 3]
    let initPercent: BigRational?
    let chainAsset: ChainAsset
    let amountRestriction: (lower: Decimal, upper: Decimal) = (lower: 0.01, upper: 50)
    let amountRecommendation: (lower: Decimal, upper: Decimal) = (lower: 0.1, upper: 2.3)

    private var percentFormatter: NumberFormatter
    private var numberFormatter: NumberFormatter
    private var amountInput: Decimal?

    init(
        wireframe: SwapSlippageWireframeProtocol,
        numberFormatterLocalizable: LocalizableResource<NumberFormatter>,
        percentFormatterLocalizable: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        initPercent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        self.wireframe = wireframe
        self.numberFormatterLocalizable = numberFormatterLocalizable
        self.percentFormatterLocalizable = percentFormatterLocalizable
        self.initPercent = initPercent
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

    private func initialPercent() -> Decimal? {
        if let percent = initPercent, percent.denominator != 0 {
            let numerator = percent.numerator.decimal(precision: 0)
            let denominator = percent.denominator.decimal(precision: 0)
            return numerator / denominator
        } else {
            return nil
        }
    }

    private func provideAmountViewModel() {
        let inputViewModel = AmountInputViewModel(
            symbol: "",
            amount: amountInput,
            limit: 100,
            formatter: numberFormatter,
            inputLocale: selectedLocale,
            precision: 1
        )

        view?.didReceiveInput(viewModel: inputViewModel)
    }

    private func provideResetButtonState() {
        let amountChanged = amountInput != initialPercent()
        view?.didReceiveResetState(available: amountChanged)
    }

    private func provideErrors() {
        if let amountInput = amountInput,
           amountInput < amountRestriction.lower || amountInput > amountRestriction.upper {
            let minAmountString = title(for: amountRestriction.lower)
            let maxAmountString = title(for: amountRestriction.upper)
            let error = R.string.localizable.swapsSetupSlippageErrorAmountBounds(
                minAmountString,
                maxAmountString,
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.didReceiveInput(error: error)
        } else {
            view?.didReceiveInput(error: nil)
        }
    }

    private func provideWarnings() {
        guard let amountInput = amountInput, amountInput > 0 else {
            view?.didReceiveInput(warning: nil)
            return
        }
        if amountInput <= amountRecommendation.lower {
            let warning = R.string.localizable.swapsSetupSlippageWarningLowAmount(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.didReceiveInput(warning: warning)
        } else if amountInput >= amountRecommendation.upper {
            let warning = R.string.localizable.swapsSetupSlippageWarningHighAmount(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.didReceiveInput(warning: warning)
        } else {
            view?.didReceiveInput(warning: nil)
        }
    }
}

extension SwapSlippagePresenter: SwapSlippagePresenterProtocol {
    func setup() {
        let viewModel = prefilledPercents.map {
            SlippagePercentViewModel(
                value: $0,
                title: title(for: $0)
            )
        }

        amountInput = initialPercent()
        provideResetButtonState()
        provideAmountViewModel()
        view?.didReceivePreFilledPercents(viewModel: viewModel)
    }

    func select(percent: SlippagePercentViewModel) {
        amountInput = percent.value
        provideAmountViewModel()
        provideResetButtonState()
        provideErrors()
        provideWarnings()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount
        provideResetButtonState()
        provideErrors()
        provideWarnings()
    }

    func showSlippageInfo() {
        // TODO: show bottomsheet
    }

    func reset() {
        amountInput = initialPercent()
        provideAmountViewModel()
        provideResetButtonState()
        provideErrors()
        provideWarnings()
    }

    func apply() {
        if let amountInput = amountInput {
            let rational = BigRational.fraction(from: amountInput)
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
