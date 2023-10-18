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
    let minAmount: Decimal = 0.01
    let maxAmount: Decimal = 50

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
        let value = percent / (percentFormatter.multiplier?.decimalValue ?? 1)
        return percentFormatter.stringFromDecimal(value) ?? ""
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
        let amountChanged = amountInput.map { fraction(from: $0) } != initPercent
        view?.didReceiveResetState(available: amountChanged)
    }

    private func provideErrors() {
        if let amountInput = amountInput, amountInput < minAmount || amountInput > maxAmount {
            let minAmountString = title(for: minAmount)
            let maxAmountString = title(for: maxAmount)
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

    private func fraction(from number: Decimal) -> BigRational {
        var roundedNumber = Decimal()
        var value = number
        NSDecimalRound(
            &roundedNumber,
            &value,
            percentFormatter.maximumFractionDigits,
            NSDecimalNumber.RoundingMode.plain
        )

        let decimalNumber = NSDecimalNumber(decimal: roundedNumber)
        let scale = -roundedNumber.exponent
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
                title: title(for: $0)
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
        provideErrors()
    }

    func updateAmount(_ amount: Decimal?) {
        amountInput = amount
        provideResetButtonState()
        provideErrors()
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
        provideErrors()
    }

    func apply() {
        if let amountInput = amountInput {
            let rational = fraction(from: amountInput)
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
