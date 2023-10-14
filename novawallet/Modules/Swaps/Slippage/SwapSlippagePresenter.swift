import Foundation
import SoraFoundation
import BigInt

final class SwapSlippagePresenter {
    weak var view: SwapSlippageViewProtocol?
    let wireframe: SwapSlippageWireframeProtocol
    let interactor: SwapSlippageInteractorInputProtocol
    let numberFormatterLocalizable: LocalizableResource<NumberFormatter>
    let percentFormatterLocalizable: LocalizableResource<NumberFormatter>
    let completionHandler: (BigRational) -> Void
    let prefilledPercents: [Decimal] = [0.1, 1, 3]

    private var percentFormatter: NumberFormatter
    private var numberFormatter: NumberFormatter
    private var amountInput: Decimal?

    init(
        interactor: SwapSlippageInteractorInputProtocol,
        wireframe: SwapSlippageWireframeProtocol,
        numberFormatterLocalizable: LocalizableResource<NumberFormatter>,
        percentFormatterLocalizable: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.numberFormatterLocalizable = numberFormatterLocalizable
        self.percentFormatterLocalizable = percentFormatterLocalizable
        self.completionHandler = completionHandler
        percentFormatter = percentFormatterLocalizable.value(for: localizationManager.selectedLocale)
        numberFormatter = numberFormatterLocalizable.value(for: localizationManager.selectedLocale)
        self.localizationManager = localizationManager
    }

    private func title(for percent: Decimal) -> String {
        percentFormatter.stringFromDecimal(percent) ?? ""
    }

    func provideAmountViewModel() {
        let inputViewModel = AmountInputViewModel(
            symbol: "",
            amount: amountInput,
            limit: 50,
            formatter: numberFormatter,
            inputLocale: selectedLocale,
            precision: 1,
            plugin: AddSymbolAmountInputFormatterPlugin()
        )

        view?.didReceiveInput(viewModel: inputViewModel)
    }

    func fraction(from number: Decimal) -> BigRational {
        let decimalNumber = NSDecimalNumber(decimal: number)
        let scale = -number.exponent
        let numerator = decimalNumber.multiplying(byPowerOf10: Int16(scale)).intValue
        let denominator = Int(truncating: pow(10, scale) as NSNumber)
        return .init(numerator: BigUInt(numerator), denominator: BigUInt(denominator))
    }
}

extension SwapSlippagePresenter: SwapSlippagePresenterProtocol {
    func setup() {
        let viewModel = prefilledPercents.map {
            Percent(
                value: $0,
                title: title(for: $0 / (percentFormatter.multiplier?.decimalValue ?? 1))
            )
        }
        view?.didReceivePreFilledPercents(viewModel: viewModel)
        provideAmountViewModel()
    }

    func select(percent: Percent) {
        amountInput = percent.value
        provideAmountViewModel()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount
    }

    func apply() {
        if let amountInput = amountInput {
            let rational = fraction(from: amountInput)
            completionHandler(rational)
        }
        wireframe.close(from: view)
    }
}

extension SwapSlippagePresenter: SwapSlippageInteractorOutputProtocol {}

extension SwapSlippagePresenter: Localizable {
    func applyLocalization() {
        percentFormatter = percentFormatterLocalizable.value(for: selectedLocale)
        numberFormatter = numberFormatterLocalizable.value(for: selectedLocale)
    }
}
