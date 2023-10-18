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
    let initPercent: BigRational?
    let chainAsset: ChainAsset

    private var percentFormatter: NumberFormatter
    private var numberFormatter: NumberFormatter
    private var amountInput: Decimal?

    init(
        interactor: SwapSlippageInteractorInputProtocol,
        wireframe: SwapSlippageWireframeProtocol,
        numberFormatterLocalizable: LocalizableResource<NumberFormatter>,
        percentFormatterLocalizable: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        initPercent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        self.interactor = interactor
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
        percentFormatter.stringFromDecimal(percent) ?? ""
    }

    func provideAmountViewModel() {
        let inputViewModel = AmountInputViewModel(
            symbol: "",
            amount: amountInput,
            limit: 50,
            formatter: numberFormatter,
            inputLocale: selectedLocale,
            precision: 1
        )

        view?.didReceiveInput(viewModel: inputViewModel)
    }

    func provideResetButtonState() {
        let amountChanged = amountInput.map { fraction(from: $0) } != initPercent
        view?.didReceiveResetState(available: amountChanged)
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
            SlippagePercentViewModel(
                value: $0,
                title: title(for: $0 / (percentFormatter.multiplier?.decimalValue ?? 1))
            )
        }

        if let percent = initPercent, percent.denominator != 0 {
            let numerator = percent.numerator.decimal(precision: chainAsset.asset.precision)
            let denominator = percent.denominator.decimal(precision: chainAsset.asset.precision)
            amountInput = numerator / denominator
        }
        provideResetButtonState()
        provideAmountViewModel()
        view?.didReceivePreFilledPercents(viewModel: viewModel)
    }

    func select(percent: SlippagePercentViewModel) {
        amountInput = percent.value
        provideAmountViewModel()
        provideResetButtonState()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount
        provideResetButtonState()
    }

    func showSlippageInfo() {
        // TODO: show bottomsheet
    }

    func reset() {
        if let initPercent = initPercent, initPercent.denominator != 0 {
            amountInput = initPercent.numerator.decimal(precision: chainAsset.asset.precision) / initPercent.denominator.decimal(precision: chainAsset.asset.precision)
        } else {
            amountInput = nil
        }

        provideAmountViewModel()
        provideResetButtonState()
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
