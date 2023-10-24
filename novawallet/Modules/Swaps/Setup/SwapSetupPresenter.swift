import Foundation
import SoraFoundation
import BigInt

final class SwapSetupPresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let viewModelFactory: SwapsSetupViewModelFactoryProtocol
    let dataValidatingFactory: SwapDataValidatorFactoryProtocol

    private(set) var payAssetBalance: AssetBalance?
    private(set) var feeAssetBalance: AssetBalance?
    private(set) var payChainAsset: ChainAsset?
    private(set) var receiveChainAsset: ChainAsset?
    private(set) var feeChainAsset: ChainAsset?
    private(set) var payAssetPriceData: PriceData?
    private(set) var receiveAssetPriceData: PriceData?
    private(set) var feeAssetPriceData: PriceData?

    private(set) var payAmountInput: AmountInputResult?
    private(set) var receiveAmountInput: Decimal?
    private(set) var fee: BigUInt?
    private(set) var quote: AssetConversion.Quote?
    private(set) var quoteArgs: AssetConversion.QuoteArgs? {
        didSet {
            provideDetailsViewModel(isAvailable: quoteArgs != nil)
        }
    }

    private var slippage: BigRational?

    private var feeIdentifier: String?
    private var accountId: AccountId?

    init(
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        viewModelFactory: SwapsSetupViewModelFactoryProtocol,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory

        self.localizationManager = localizationManager
    }

    private func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            assetIn: payChainAsset?.chainAssetId,
            assetOut: receiveChainAsset?.chainAssetId,
            amountIn: getPayAmount(for: payAmountInput),
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
            maxValue: payAssetBalance?.transferable,
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
            amount: getPayAmount(for: payAmountInput),
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
            amount: getPayAmount(for: payAmountInput),
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

    private func provideSettingsState() {
        view?.didReceiveSettingsState(isAvailable: payChainAsset != nil)
    }

    private func getPayAmount(for input: AmountInputResult?) -> Decimal? {
        guard let input = input, let balanceMinusFee = balanceMinusFee() else {
            return nil
        }
        return input.absoluteValue(from: balanceMinusFee)
    }

    private func getSpendingAmount() -> Decimal? {
        guard let input = payAmountInput, let payChainAsset = payChainAsset else {
            return nil
        }
        guard let transferableBalance = Decimal.fromSubstrateAmount(
            payAssetBalance?.transferable ?? 0,
            precision: Int16(payChainAsset.assetDisplayInfo.assetPrecision)
        ) else {
            return nil
        }
        return input.absoluteValue(from: transferableBalance)
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
        guard quoteArgs != nil, let feeChainAsset = feeChainAsset else {
            return
        }
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let viewModel = viewModelFactory.feeViewModel(
            amount: fee,
            assetDisplayInfo: feeChainAsset.assetDisplayInfo,
            priceData: feeAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    func estimateFee() {
        guard let quote = quote,
              let accountId = accountId,
              let quoteArgs = quoteArgs,
              let slippage = slippage else {
            return
        }

        let args = AssetConversion.CallArgs(
            assetIn: quote.assetIn,
            amountIn: quote.amountIn,
            assetOut: quote.assetOut,
            amountOut: quote.amountOut,
            receiver: accountId,
            direction: quoteArgs.direction,
            slippage: slippage
        )

        guard args.identifier != feeIdentifier else {
            return
        }

        feeIdentifier = args.identifier
        interactor.calculateFee(args: args)
    }

    func refreshQuote(direction: AssetConversion.Direction, forceUpdate: Bool = true) {
        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset else {
            return
        }

        quote = nil

        switch direction {
        case .buy:
            refreshQuoteForBuy(
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset,
                forceUpdate: forceUpdate
            )
        case .sell:
            refreshQuoteForSell(
                payChainAsset: payChainAsset,
                receiveChainAsset: receiveChainAsset,
                forceUpdate: forceUpdate
            )
        }

        provideRateViewModel()
        provideFeeViewModel()
    }

    private func refreshQuoteForBuy(payChainAsset: ChainAsset, receiveChainAsset: ChainAsset, forceUpdate: Bool) {
        if
            let receiveInPlank = receiveAmountInput?.toSubstrateAmount(
                precision: receiveChainAsset.assetDisplayInfo.assetPrecision
            ),
            receiveInPlank > 0 {
            let quoteArgs = AssetConversion.QuoteArgs(
                assetIn: payChainAsset.chainAssetId,
                assetOut: receiveChainAsset.chainAssetId,
                amount: receiveInPlank,
                direction: .buy
            )
            self.quoteArgs = quoteArgs
            interactor.calculateQuote(for: quoteArgs)
        } else {
            quoteArgs = nil
            if forceUpdate {
                payAmountInput = nil
                providePayAmountInputViewModel()
            } else {
                refreshQuote(direction: .sell)
            }
        }
    }

    private func refreshQuoteForSell(payChainAsset: ChainAsset, receiveChainAsset: ChainAsset, forceUpdate: Bool) {
        if let payInPlank = getPayAmount(for: payAmountInput)?.toSubstrateAmount(
            precision: Int16(payChainAsset.assetDisplayInfo.assetPrecision)), payInPlank > 0 {
            let quoteArgs = AssetConversion.QuoteArgs(
                assetIn: payChainAsset.chainAssetId,
                assetOut: receiveChainAsset.chainAssetId,
                amount: payInPlank,
                direction: .sell
            )
            self.quoteArgs = quoteArgs
            interactor.calculateQuote(for: quoteArgs)
        } else {
            quoteArgs = nil
            if forceUpdate {
                receiveAmountInput = nil
                provideReceiveAmountInputViewModel()
            } else {
                refreshQuote(direction: .buy)
            }
        }
    }

    func balanceMinusFee() -> Decimal? {
        guard let payChainAsset = payChainAsset else {
            return nil
        }
        let balanceValue = payAssetBalance?.transferable ?? 0
        let feeValue = payChainAsset.chainAssetId == feeChainAsset?.chainAssetId ? fee : 0

        let precision = Int16(payChainAsset.asset.precision)

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue ?? 0, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func handleAssetBalanceError(chainAssetId: ChainAssetId) {
        switch chainAssetId {
        case payChainAsset?.chainAssetId:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.payChainAsset.map { self?.interactor.update(payChainAsset: $0) }
            }
        case feeChainAsset?.chainAssetId:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.feeChainAsset.map { self?.interactor.update(feeChainAsset: $0) }
            }
        default:
            break
        }
    }

    func handlePriceError(priceId: AssetModel.PriceId) {
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            guard let self = self else {
                return
            }
            [self.payChainAsset, self.receiveChainAsset, self.feeChainAsset]
                .compactMap { $0 }
                .filter { $0.asset.priceId == priceId }
                .forEach(self.interactor.remakePriceSubscription)
        }
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel(isAvailable: false)
        provideButtonState()
        provideSettingsState()
        // TODO: get from settings
        slippage = .fraction(from: 0.5)?.fromPercents()
        interactor.setup()
    }

    func selectPayToken() {
        wireframe.showPayTokenSelection(from: view, chainAsset: receiveChainAsset) { [weak self] chainAsset in
            self?.payChainAsset = chainAsset
            // TODO: select fee asset
            self?.feeChainAsset = chainAsset.chain.utilityAsset().map {
                ChainAsset(chain: chainAsset.chain, asset: $0)
            }
            self?.providePayAssetViews()
            self?.provideButtonState()
            self?.provideSettingsState()
            self?.refreshQuote(direction: .sell, forceUpdate: false)
            self?.interactor.update(payChainAsset: chainAsset)
        }
    }

    func selectReceiveToken() {
        wireframe.showReceiveTokenSelection(from: view, chainAsset: payChainAsset) { [weak self] chainAsset in
            self?.receiveChainAsset = chainAsset
            self?.provideReceiveAssetViews()
            self?.provideButtonState()
            self?.refreshQuote(direction: .buy, forceUpdate: false)
            self?.interactor.update(receiveChainAsset: chainAsset)
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }
        refreshQuote(direction: .sell)
        provideButtonState()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        refreshQuote(direction: .buy)
        provideButtonState()
    }

    func swap() {
        Swift.swap(&payChainAsset, &receiveChainAsset)
        interactor.update(payChainAsset: payChainAsset)
        interactor.update(receiveChainAsset: receiveChainAsset)
        payAmountInput = nil
        receiveAmountInput = nil
        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        provideSettingsState()
        refreshQuote(direction: .sell, forceUpdate: false)
    }

    func selectMaxPayAmount() {
        payAmountInput = .rate(1)
        providePayAssetViews()
        refreshQuote(direction: .sell)
        provideButtonState()
    }

    // TODO: show editing fee
    func showFeeActions() {}

    func showFeeInfo() {
        let title = LocalizableResource {
            R.string.localizable.commonNetwork(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsNetworkFeeDescription(
                preferredLanguages: $0.rLanguages
            )
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showRateInfo() {
        let title = LocalizableResource {
            R.string.localizable.swapsSetupDetailsRate(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsRateDescription(
                preferredLanguages: $0.rLanguages
            )
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func proceed() {
        guard let payChainAsset = payChainAsset, let feeChainAsset = feeChainAsset else {
            return
        }
        let validators = validators(
            spendingAmount: getSpendingAmount(),
            payChainAsset: payChainAsset,
            feeChainAsset: feeChainAsset
        )
        DataValidationRunner(validators: validators).runValidation { [weak self] in
            // TODO: Show confirm screen
        }
    }

    func showSettings() {
        guard let payChainAsset = payChainAsset else {
            return
        }
        wireframe.showSettings(
            from: view,
            percent: slippage,
            chainAsset: payChainAsset
        ) { [weak self, payChainAsset] slippageValue in
            guard payChainAsset.chainAssetId == self?.payChainAsset?.chainAssetId else {
                return
            }
            self?.slippage = slippageValue
            self?.estimateFee()
        }
    }
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceive(error: SwapSetupError) {
        switch error {
        case let .quote(_, args):
            guard args == quoteArgs else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshQuote(direction: args.direction)
            }
        case let .fetchFeeFailed(_, id):
            guard id == feeIdentifier else {
                return
            }
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            handlePriceError(priceId: priceId)
        case let .assetBalance(_, chainAssetId, _):
            handleAssetBalanceError(chainAssetId: chainAssetId)
        }
    }

    func didReceive(quote: AssetConversion.Quote, for quoteArgs: AssetConversion.QuoteArgs) {
        guard quoteArgs == self.quoteArgs else {
            return
        }

        self.quote = quote

        switch quoteArgs.direction {
        case .buy:
            let payAmount = payChainAsset.map {
                Decimal.fromSubstrateAmount(
                    quote.amountIn,
                    precision: Int16($0.asset.precision)
                ) ?? 0
            }
            payAmountInput = payAmount.map { .absolute($0) }
            providePayAmountInputViewModel()
        case .sell:
            receiveAmountInput = receiveChainAsset.map {
                Decimal.fromSubstrateAmount(
                    quote.amountOut,
                    precision: $0.asset.displayInfo.assetPrecision
                ) ?? 0
            }
            provideReceiveAmountInputViewModel()
        }

        provideRateViewModel()
        estimateFee()
        provideButtonState()
    }

    func didReceive(fee: BigUInt?, transactionId: TransactionFeeId) {
        guard feeIdentifier == transactionId else {
            return
        }
        self.fee = fee
        provideFeeViewModel()
        provideButtonState()
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        if priceId == payChainAsset?.asset.priceId {
            payAssetPriceData = price
            providePayInputPriceViewModel()
        }
        if priceId == receiveChainAsset?.asset.priceId {
            receiveAssetPriceData = price
            provideReceiveInputPriceViewModel()
        }
        if priceId == feeChainAsset?.asset.priceId {
            feeAssetPriceData = price
            provideFeeViewModel()
        }
    }

    func didReceive(payAccountId: AccountId?) {
        accountId = payAccountId
    }

    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId, accountId _: AccountId) {
        if chainAsset == payChainAsset?.chainAssetId {
            payAssetBalance = balance
            providePayTitle()
        }
        if chainAsset == feeChainAsset?.chainAssetId {
            feeAssetBalance = balance
            if case .rate = payAmountInput {
                providePayInputPriceViewModel()
                providePayAmountInputViewModel()
                provideButtonState()
            }
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
