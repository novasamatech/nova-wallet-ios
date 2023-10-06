import Foundation
import SoraFoundation
import BigInt

final class SwapSetupPresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let viewModelFactory: SwapsSetupViewModelFactoryProtocol

    private var assetBalance: AssetBalance?
    private var payChainAsset: ChainAsset?
    private var payAssetPriceData: PriceData?
    private var receiveAssetPriceData: PriceData?
    private var receiveChainAsset: ChainAsset?
    private var payAmountInput: AmountInputResult?
    private var receiveAmountInput: Decimal?
    private var quote: AssetConversion.Quote?
    private var direction: AssetConversion.Direction?

    init(
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        viewModelFactory: SwapsSetupViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func estimateFee() {}

    private func quote(amount: BigUInt, direction: AssetConversion.Direction) {
        guard let assetIn = payChainAsset?.chainAssetId,
              let assetOut = receiveChainAsset?.chainAssetId else {
            return
        }
        self.direction = direction
        interactor.calculateQuote(for: .init(
            assetIn: assetIn,
            assetOut: assetOut,
            amount: amount,
            direction: direction
        ))
    }

    private func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            assetIn: payChainAsset?.chainAssetId,
            assetOut: receiveChainAsset?.chainAssetId,
            amountIn: absoluteValue(for: payAmountInput),
            amountOut: receiveAmountInput
        )
        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled
        )
    }

    private func providePayTitle() {
        let payTitleViewModel = viewModelFactory.payTitleViewModel(
            assetDisplayInfo: payChainAsset?.assetDisplayInfo,
            maxValue: assetBalance?.transferable,
            locale: selectedLocale
        )
        view?.didReceiveTitle(payViewModel: payTitleViewModel)
    }

    private func providePayAssetViewModel() {
        let payAssetViewModel = viewModelFactory.payAssetViewModel(
            chainAsset: payChainAsset,
            locale: selectedLocale
        )
        view?.didReceiveInputChainAsset(payViewModel: payAssetViewModel)
    }

    private func providePayInputPriceViewModel() {
        guard let assetDisplayInfo = payChainAsset?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(payViewModel: nil)
            return
        }
        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: absoluteValue(for: payAmountInput),
            priceData: payAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAmountInputPrice(payViewModel: inputPriceViewModel)
    }

    private func provideReceiveTitle() {
        let receiveTitleViewModel = viewModelFactory.receiveTitleViewModel(locale: selectedLocale)
        view?.didReceiveTitle(receiveViewModel: receiveTitleViewModel)
    }

    private func provideReceiveAssetViewModel() {
        let receiveAssetViewModel = viewModelFactory.receiveAssetViewModel(
            chainAsset: receiveChainAsset,
            locale: selectedLocale
        )
        view?.didReceiveInputChainAsset(receiveViewModel: receiveAssetViewModel)
    }

    private func provideReceiveInputPriceViewModel() {
        guard let assetDisplayInfo = receiveChainAsset?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(receiveViewModel: nil)
            return
        }
        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: receiveAmountInput,
            priceData: receiveAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAmountInputPrice(receiveViewModel: inputPriceViewModel)
    }

    private func providePayAmountInputViewModel() {
        guard let payChainAsset = payChainAsset else {
            return
        }
        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: payChainAsset,
            amount: absoluteValue(for: payAmountInput),
            locale: selectedLocale
        )
        view?.didReceiveAmount(payInputViewModel: amountInputViewModel)
    }

    private func provideReceiveAmountInputViewModel() {
        guard let receiveChainAsset = receiveChainAsset else {
            return
        }
        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: receiveChainAsset,
            amount: receiveAmountInput,
            locale: selectedLocale
        )
        view?.didReceiveAmount(receiveInputViewModel: amountInputViewModel)
    }

    private func absoluteValue(for input: AmountInputResult?) -> Decimal? {
        guard
            let input = input,
            let assetBalance = assetBalance,
            let payChainAsset = payChainAsset else {
            return nil
        }
        guard let transferrableBalanceDecimal =
            Decimal.fromSubstrateAmount(
                assetBalance.transferable,
                precision: payChainAsset.asset.displayInfo.assetPrecision
            ) else {
            return nil
        }

        return input.absoluteValue(from: transferrableBalanceDecimal)
    }

    private func providePayAssetViews() {
        providePayTitle()
        providePayAssetViewModel()
        providePayInputPriceViewModel()
        providePayAmountInputViewModel()
    }

    private func provideReceiveAssetViews() {
        provideReceiveTitle()
        provideReceiveAssetViewModel()
        provideReceiveInputPriceViewModel()
        provideReceiveAmountInputViewModel()
    }

    private func provideRateViewModel() {
        guard
            let assetDisplayInfoIn = payChainAsset?.assetDisplayInfo,
            let assetDisplayInfoOut = receiveChainAsset?.assetDisplayInfo,
            let quote = quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }
        let rateViewModel = viewModelFactory.rate(from: .init(
            assetDisplayInfoIn: assetDisplayInfoIn,
            assetDisplayInfoOut: assetDisplayInfoOut,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        ), locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        interactor.setup()
    }

    func selectPayToken() {
        wireframe.showPayTokenSelection(from: view) { [weak self] chainAsset in
            self?.payChainAsset = chainAsset
            self?.providePayAssetViews()
        }
    }

    func selectReceiveToken() {
        wireframe.showReceiveTokenSelection(from: view) { [weak self] chainAsset in
            self?.receiveChainAsset = chainAsset
            self?.provideReceiveAssetViews()
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }

        if
            let chainAsset = payChainAsset,
            let amount = amount,
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) {
            quote(amount: amountInPlank, direction: .sell)
        }
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        if
            let chainAsset = receiveChainAsset,
            let amount = amount,
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) {
            quote(amount: amountInPlank, direction: .buy)
        }
    }

    // TODO: implement
    func swap() {
        Swift.swap(&payChainAsset, &receiveChainAsset)
        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
    }

    // TODO: navigate to confirm screen
    func proceed() {}
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceive(error: SwapSetupError) {
        print("=================", error)
    }

    func didReceive(quote: AssetConversion.Quote) {
        self.quote = quote

        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset,
            quote.assetIn == payChainAsset.chainAssetId,
            quote.assetOut == receiveChainAsset.chainAssetId else {
            return
        }

        switch direction {
        case .buy:
            let payAmount = Decimal.fromSubstrateAmount(
                quote.amountIn,
                precision: Int16(payChainAsset.asset.precision)
            ) ?? 0
            payAmountInput = .absolute(payAmount)
            providePayInputPriceViewModel()
        case .sell:
            receiveAmountInput = Decimal.fromSubstrateAmount(
                quote.amountOut,
                precision: Int16(receiveChainAsset.asset.precision)
            ) ?? 0
            provideReceiveAmountInputViewModel()
        default:
            break
        }

        provideRateViewModel()
    }

    func didReceive(fee _: BigUInt?) {}
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            setup()
        }
    }
}
