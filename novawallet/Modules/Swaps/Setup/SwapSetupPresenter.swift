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
    private var direction: AssetConversion.Direction?
    private var fee: BigUInt?
    private var quote: AssetConversion.Quote?

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

    private func quote(
        amount: BigUInt,
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        direction: AssetConversion.Direction
    ) {
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
            let payChainAsset = payChainAsset else {
            return nil
        }
        guard let transferrableBalanceDecimal =
            Decimal.fromSubstrateAmount(
                assetBalance?.transferable ?? 0,
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

    private func provideDetailsViewModel(isAvailable: Bool) {
        view?.didReceiveDetailsState(isAvailable: isAvailable)
    }

    private func provideRateViewModel() {
        guard
            let assetDisplayInfoIn = payChainAsset?.assetDisplayInfo,
            let assetDisplayInfoOut = receiveChainAsset?.assetDisplayInfo,
            let quote = quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }
        let rateViewModel = viewModelFactory.rateViewModel(from: .init(
            assetDisplayInfoIn: assetDisplayInfoIn,
            assetDisplayInfoOut: assetDisplayInfoOut,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        ), locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }

    private func provideFeeViewModel() {
        guard let payChainAsset = payChainAsset, receiveChainAsset != nil else {
            return
        }
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let viewModel = viewModelFactory.feeViewModel(
            amount: fee,
            assetDisplayInfo: payChainAsset.assetDisplayInfo,
            priceData: payAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func estimateFee() {
        guard let quote = quote else {
            return
        }

        // TODO: Remove hardcode slippage and direction
        interactor.calculateFee(
            for: quote,
            slippage: .init(direction: .sell, slippage: 1)
        )
    }

    private func refreshQuote() {
        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset else {
            return
        }
        var isCalculating: Bool = false

        switch direction {
        case .buy:
            if let receiveInPlank = receiveAmountInput?.toSubstrateAmount(precision: Int16(receiveChainAsset.asset.precision)), receiveInPlank > 0 {
                quote(
                    amount: receiveInPlank,
                    assetIn: payChainAsset.chainAssetId,
                    assetOut: receiveChainAsset.chainAssetId,
                    direction: .buy
                )
                isCalculating = true
            }
            payAmountInput = nil
            providePayAmountInputViewModel()
        case .sell:
            if let payInPlank = absoluteValue(for: payAmountInput)?.toSubstrateAmount(
                precision: Int16(payChainAsset.asset.precision)), payInPlank > 0 {
                quote(
                    amount: payInPlank,
                    assetIn: payChainAsset.chainAssetId,
                    assetOut: receiveChainAsset.chainAssetId,
                    direction: .sell
                )
                isCalculating = true
            }

            receiveAmountInput = nil
            provideReceiveAmountInputViewModel()
        default:
            break
        }
        provideDetailsViewModel(isAvailable: isCalculating)
        provideRateViewModel()
        provideFeeViewModel()
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel(isAvailable: false)
        provideButtonState()
        interactor.setup()
    }

    func selectPayToken() {
        wireframe.showPayTokenSelection(from: view) { [weak self] chainAsset in
            self?.payChainAsset = chainAsset
            self?.providePayAssetViews()
            self?.refreshQuote()
            self?.interactor.update(payChainAsset: chainAsset)
        }
    }

    func selectReceiveToken() {
        wireframe.showReceiveTokenSelection(from: view) { [weak self] chainAsset in
            self?.receiveChainAsset = chainAsset
            self?.provideReceiveAssetViews()
            self?.refreshQuote()
            self?.interactor.update(receiveChainAsset: chainAsset)
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }
        direction = .sell
        refreshQuote()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        direction = .buy
        refreshQuote()
    }

    func swap() {
        Swift.swap(&payChainAsset, &receiveChainAsset)
        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        quote = nil
        refreshQuote()
    }

    // TODO: show editing fee
    func showFeeActions() {}

    // TODO: show fee information
    func showFeeInfo() {}

    // TODO: show rate information
    func showRateInfo() {}

    // TODO: navigate to confirm screen
    func proceed() {}
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceive(error: SwapSetupError) {
        switch error {
        case .quote:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshQuote()
            }
        case .fetchFeeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        }
    }

    func didReceive(quote: AssetConversion.Quote) {
        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset,
            quote.assetIn == payChainAsset.chainAssetId,
            quote.assetOut == receiveChainAsset.chainAssetId else {
            return
        }

        self.quote = quote

        switch direction {
        case .buy:
            let payAmount = Decimal.fromSubstrateAmount(
                quote.amountIn,
                precision: Int16(payChainAsset.asset.precision)
            ) ?? 0
            payAmountInput = .absolute(payAmount)
            providePayAmountInputViewModel()
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
        estimateFee()
    }

    func didReceive(fee: BigUInt?) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        if payChainAsset?.asset.priceId == priceId {
            payAssetPriceData = price
            providePayInputPriceViewModel()
        } else if receiveChainAsset?.asset.priceId == priceId {
            receiveAssetPriceData = price
            provideReceiveInputPriceViewModel()
        }
    }
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            setup()
        }
    }
}
