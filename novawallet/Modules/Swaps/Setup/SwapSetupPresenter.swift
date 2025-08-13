import Foundation
import Foundation_iOS
import BigInt

final class SwapSetupPresenter: SwapBasePresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let initState: SwapSetupInitState

    private(set) var viewModelFactory: SwapsSetupViewModelFactoryProtocol

    private(set) var quoteArgs: AssetConversion.QuoteArgs? {
        didSet {
            provideDetailsViewModel()
        }
    }

    private var payAmountInput: AmountInputResult?
    private var receiveAmountInput: Decimal?

    private var canPayFeeInPayAsset: Bool = false
    private var payChainAsset: ChainAsset?
    private var receiveChainAsset: ChainAsset?
    private var feeChainAsset: ChainAsset?

    private var slippage: BigRational

    private var detailsAvailable: Bool {
        !quoteResult.hasError() && quoteArgs != nil
    }

    /*
     *  We might have cases when quote recalcution triggers fee recalculation and vice versa
     *  and we want to bound such triggers to avoid deadlock.
     */
    private var maxCorrectionCounter = MaxCounter.feeCorrection()

    init(
        initState: SwapSetupInitState,
        interactor: SwapSetupInteractorInputProtocol,
        wireframe: SwapSetupWireframeProtocol,
        viewModelFactory: SwapsSetupViewModelFactoryProtocol,
        priceDiffModelFactory: SwapPriceDifferenceModelFactoryProtocol,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        priceStore: AssetExchangePriceStoring,
        localizationManager: LocalizationManagerProtocol,
        selectedWallet: MetaAccountModel,
        slippageConfig: SlippageConfig,
        logger: LoggerProtocol
    ) {
        self.initState = initState
        payChainAsset = initState.payChainAsset
        feeChainAsset = initState.feeChainAsset ?? payChainAsset?.chain.utilityChainAsset()
        receiveChainAsset = initState.receiveChainAsset

        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        slippage = slippageConfig.defaultSlippage

        super.init(
            selectedWallet: selectedWallet,
            dataValidatingFactory: dataValidatingFactory,
            priceDiffFactory: priceDiffModelFactory,
            priceStore: priceStore,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    // MARK: Base implementation

    override func getSpendingInputAmount() -> Decimal? {
        guard let payAmountInput = payAmountInput else {
            return nil
        }

        let maxAmount = getMaxModel().calculate()
        return payAmountInput.absoluteValue(from: maxAmount)
    }

    override func getPayChainAsset() -> ChainAsset? {
        payChainAsset
    }

    override func getReceiveChainAsset() -> ChainAsset? {
        receiveChainAsset
    }

    override func getFeeChainAsset() -> ChainAsset? {
        feeChainAsset
    }

    override func getQuoteArgs() -> AssetConversion.QuoteArgs? {
        quoteArgs
    }

    override func getSlippage() -> BigRational {
        slippage
    }

    override func shouldHandleRoute(for args: AssetConversion.QuoteArgs?) -> Bool {
        quoteArgs == args
    }

    override func estimateFee() {
        guard let quote, let feeChainAsset else {
            return
        }

        fee = nil
        provideFeeViewModel()

        interactor.calculateFee(for: quote.route, slippage: slippage, feeAsset: feeChainAsset)
    }

    override func applySwapMax() {
        payAmountInput = .rate(1)
        providePayAssetViews()
        refreshQuote(direction: .sell)
        provideButtonState()
        provideIssues()
    }

    override func handleBaseError(_ error: SwapBaseError) {
        handleBaseError(
            error,
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            locale: selectedLocale
        )

        provideIssues()
        provideDetailsViewModel()
    }

    override func handleNewQuote(_ quote: AssetExchangeQuote, for quoteArgs: AssetConversion.QuoteArgs) {
        logger.debug("New quote: \(quote)")

        if let fee, !quote.hasSamePath(other: fee.route) {
            // we need to keep fee in sync with quote
            self.fee = nil
            maxCorrectionCounter.resetCounter()
        }

        switch quoteArgs.direction {
        case .buy:
            let payAmount = payChainAsset.map {
                quote.route.quote.decimal(assetInfo: $0.asset.displayInfo)
            }

            payAmountInput = payAmount.map { .absolute($0) }
            providePayAmountInputViewModel()
            providePayInputPriceViewModel()
            provideReceiveInputPriceViewModel()
        case .sell:
            receiveAmountInput = receiveChainAsset.map {
                quote.route.quote.decimal(assetInfo: $0.asset.displayInfo)
            }

            provideReceiveAmountInputViewModel()
            provideReceiveInputPriceViewModel()
            providePayInputPriceViewModel()
        }

        provideRateViewModel()
        provideRouteViewModel()
        provideExecutionTimeViewModel()
        provideButtonState()
        provideDetailsViewModel()
        estimateFee()
    }

    override func handleNewFee(
        _: AssetExchangeFee?,
        feeChainAssetId _: ChainAssetId?
    ) {
        provideFeeViewModel()

        if case .rate = payAmountInput {
            providePayAmountInputViewModel()
            providePayInputPriceViewModel()

            /*
             * As fee changes the max amount we might also refresh the quote but make sure
             * no deadlock.
             */
            if maxCorrectionCounter.incrementCounterIfPossible() {
                refreshQuote(direction: quoteArgs?.direction ?? .sell, forceUpdate: false)
            } else {
                maxCorrectionCounter.resetCounter()
            }
        }

        provideButtonState()
        provideIssues()
        provideFeeViewModel()
        provideRouteViewModel()
        providePayTitle()
        switchFeeChainAssetIfNecessary()
    }

    override func handleNewPrice(_: PriceData?, priceId: AssetModel.PriceId) {
        if payChainAsset?.asset.priceId == priceId {
            providePayInputPriceViewModel()
        }

        if receiveChainAsset?.asset.priceId == priceId {
            provideReceiveInputPriceViewModel()
        }

        if feeChainAsset?.asset.priceId == priceId {
            provideFeeViewModel()
        }
    }

    override func handleNewBalance(_: AssetBalance?, for chainAsset: ChainAssetId) {
        if payChainAsset?.chainAssetId == chainAsset {
            providePayTitle()

            if case .rate = payAmountInput {
                providePayInputPriceViewModel()
                providePayAmountInputViewModel()
                provideButtonState()
            }
        }

        provideIssues()
        switchFeeChainAssetIfNecessary()
    }

    override func handleNewBalanceExistense(_: AssetBalanceExistence, chainAssetId _: ChainAssetId) {
        if case .rate = payAmountInput {
            providePayInputPriceViewModel()
            providePayAmountInputViewModel()
            provideButtonState()
        }

        providePayTitle()
        provideIssues()
    }

    override func handleNewAccountInfo(_: AccountInfo?, chainId _: ChainModel.Id) {
        if case .rate = payAmountInput {
            providePayInputPriceViewModel()
            providePayAmountInputViewModel()
            provideButtonState()
        }
    }
}

extension SwapSetupPresenter {
    private func getPayAmount(for input: AmountInputResult?) -> Decimal? {
        guard let input = input else {
            return nil
        }

        let maxAmount = getMaxModel().calculate()
        return input.absoluteValue(from: maxAmount)
    }

    func getIssueParams() -> SwapIssueCheckParams {
        .init(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            payAmount: getSpendingInputAmount(),
            receiveAmount: receiveAmountInput,
            payAssetBalance: payAssetBalance,
            receiveAssetBalance: receiveAssetBalance,
            payAssetExistense: payAssetBalanceExistense,
            receiveAssetExistense: receiveAssetBalanceExistense,
            quoteResult: quoteResult,
            fee: fee
        )
    }

    private func providePayTitle() {
        let payTitleViewModel = if let payChainAsset, payAssetBalance != nil {
            viewModelFactory.payTitleViewModel(
                assetDisplayInfo: payChainAsset.assetDisplayInfo,
                maxValue: getMaxModel().calculate(),
                locale: selectedLocale
            )
        } else {
            viewModelFactory.payTitleViewModel(
                assetDisplayInfo: nil,
                maxValue: nil,
                locale: selectedLocale
            )
        }

        view?.didReceiveTitle(payViewModel: payTitleViewModel)
    }

    private func providePayAssetViewModel() {
        let payAssetViewModel = viewModelFactory.payAssetViewModel(
            chainAsset: payChainAsset,
            locale: selectedLocale
        )

        view?.didReceiveInputChainAsset(payViewModel: payAssetViewModel)
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
        let receiveTitleViewModel = viewModelFactory.receiveTitleViewModel(
            for: selectedLocale
        )

        view?.didReceiveTitle(receiveViewModel: receiveTitleViewModel)
    }

    private func provideReceiveAssetViewModel() {
        let receiveAssetViewModel = viewModelFactory.receiveAssetViewModel(
            chainAsset: receiveChainAsset,
            locale: selectedLocale
        )

        view?.didReceiveInputChainAsset(receiveViewModel: receiveAssetViewModel)
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

        let differenceViewModel: DifferenceViewModel?
        if let quote, let payAssetDisplayInfo = payChainAsset?.assetDisplayInfo {
            let params = RateParams(
                assetDisplayInfoIn: payAssetDisplayInfo,
                assetDisplayInfoOut: assetDisplayInfo,
                amountIn: quote.route.amountIn,
                amountOut: quote.route.amountOut
            )

            differenceViewModel = viewModelFactory.priceDifferenceViewModel(
                rateParams: params,
                priceIn: payAssetPriceData,
                priceOut: receiveAssetPriceData,
                locale: selectedLocale
            )
        } else {
            differenceViewModel = nil
        }

        view?.didReceiveAmountInputPrice(receiveViewModel: .init(
            price: inputPriceViewModel,
            difference: differenceViewModel
        ))
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

    private func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            for: getIssueParams(),
            locale: selectedLocale
        )

        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled
        )
    }

    private func provideSettingsState() {
        view?.didReceiveSettingsState(isAvailable: payChainAsset != nil)
    }

    private func provideDetailsViewModel() {
        view?.didReceiveDetailsState(isAvailable: detailsAvailable)
    }

    private func provideRateViewModel() {
        guard
            let assetDisplayInfoIn = payChainAsset?.assetDisplayInfo,
            let assetDisplayInfoOut = receiveChainAsset?.assetDisplayInfo,
            let quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }
        let rateViewModel = viewModelFactory.rateViewModel(
            from: .init(
                assetDisplayInfoIn: assetDisplayInfoIn,
                assetDisplayInfoOut: assetDisplayInfoOut,
                amountIn: quote.route.amountIn,
                amountOut: quote.route.amountOut
            ),
            locale: selectedLocale
        )

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }

    private func provideRouteViewModel() {
        guard let quote, fee != nil else {
            view?.didReceiveRoute(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.routeViewModel(from: quote.metaOperations)

        view?.didReceiveRoute(viewModel: .loaded(value: viewModel))
    }

    private func provideFeeViewModel() {
        guard
            let operations = quote?.metaOperations,
            let totalFeeInFiat = fee?.calculateTotalFeeInFiat(
                matching: operations,
                priceStore: priceStore
            ) else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.feeViewModel(
            amountInFiat: totalFeeInFiat,
            isEditable: false,
            currencyId: feeAssetPriceData?.currencyId,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func provideExecutionTimeViewModel() {
        guard let quote else {
            view?.didReceiveExecutionTime(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.executionTimeViewModel(
            from: quote.totalExecutionTime(),
            locale: selectedLocale
        )

        view?.didReceiveExecutionTime(viewModel: .loaded(value: viewModel))
    }

    private func provideIssues() {
        let issues = viewModelFactory.detectIssues(in: getIssueParams(), locale: selectedLocale)
        view?.didReceive(issues: issues)
    }

    func refreshQuote(direction: AssetConversion.Direction, forceUpdate: Bool = true) {
        guard
            let payChainAsset = payChainAsset,
            let receiveChainAsset = receiveChainAsset else {
            return
        }

        if forceUpdate {
            quoteResult = nil
        }

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
        provideRouteViewModel()
        provideExecutionTimeViewModel()
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
                provideIssues()
                provideFeeViewModel()
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
                provideReceiveInputPriceViewModel()
                provideIssues()
                provideFeeViewModel()
            } else {
                refreshQuote(direction: .buy)
            }
        }
    }

    private func updateFeeChainAsset(_ chainAsset: ChainAsset?) {
        feeChainAsset = chainAsset
        providePayAssetViews()
        interactor.update(feeChainAsset: chainAsset)

        fee = nil
        provideFeeViewModel()

        estimateFee()
    }

    private func updateViews() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel()
        provideButtonState()
        provideSettingsState()
        provideIssues()
    }

    private func switchFeeChainAssetIfNecessary() {
        guard let preferredFeeAssetModel = SwapPreferredFeeAssetModel(
            payChainAsset: payChainAsset,
            feeChainAsset: feeChainAsset,
            utilityAssetBalance: utilityAssetBalance,
            payAssetBalance: payAssetBalance,
            utilityExistenceBalance: utilityAssetBalanceExistense,
            feeModel: fee,
            canPayFeeInPayAsset: canPayFeeInPayAsset
        ) else {
            return
        }

        let newFeeAsset = preferredFeeAssetModel.deriveNewFeeAsset()

        if newFeeAsset.chainAssetId != feeChainAsset?.chainAssetId {
            logger.debug("New fee token: \(newFeeAsset.asset.symbol)")

            updateFeeChainAsset(newFeeAsset)
        }
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        updateViews()

        interactor.setup()
        interactor.update(payChainAsset: payChainAsset)
        interactor.update(feeChainAsset: feeChainAsset)
        interactor.update(receiveChainAsset: receiveChainAsset)

        if let amount = initState.amount, let direction = initState.direction {
            switch direction {
            case .sell:
                updatePayAmount(amount)
                providePayAssetViews()
            case .buy:
                updateReceiveAmount(amount)
                provideReceiveAssetViews()
            }
        }
    }

    func selectPayToken() {
        wireframe.showPayTokenSelection(from: view, chainAsset: receiveChainAsset) { [weak self] chainAsset in
            self?.payChainAsset = chainAsset
            let feeChainAsset = chainAsset.chain.utilityChainAsset()

            self?.feeChainAsset = feeChainAsset
            self?.fee = nil
            self?.canPayFeeInPayAsset = false

            self?.providePayAssetViews()
            self?.provideButtonState()
            self?.provideSettingsState()
            self?.provideFeeViewModel()
            self?.provideIssues()

            self?.interactor.update(payChainAsset: chainAsset)
            self?.interactor.update(feeChainAsset: feeChainAsset)

            if let direction = self?.quoteArgs?.direction {
                self?.refreshQuote(direction: direction, forceUpdate: false)
            } else if self?.payAmountInput != nil {
                self?.refreshQuote(direction: .sell, forceUpdate: false)
            } else {
                self?.refreshQuote(direction: .buy, forceUpdate: false)
            }
        }
    }

    func selectReceiveToken() {
        wireframe.showReceiveTokenSelection(from: view, chainAsset: payChainAsset) { [weak self] chainAsset in
            self?.receiveChainAsset = chainAsset
            self?.provideReceiveAssetViews()
            self?.provideButtonState()
            self?.provideIssues()

            self?.interactor.update(receiveChainAsset: chainAsset)

            if let direction = self?.quoteArgs?.direction {
                self?.refreshQuote(direction: direction, forceUpdate: false)
            } else if self?.receiveAmountInput != nil {
                self?.refreshQuote(direction: .buy, forceUpdate: false)
            } else {
                self?.refreshQuote(direction: .sell, forceUpdate: false)
            }
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }
        refreshQuote(direction: .sell)
        providePayInputPriceViewModel()
        provideReceiveInputPriceViewModel()
        provideButtonState()
        provideIssues()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        refreshQuote(direction: .buy)
        provideReceiveInputPriceViewModel()
        providePayInputPriceViewModel()
        provideButtonState()
        provideIssues()
    }

    func flip(currentFocus: TextFieldFocus?) {
        let payAmount = getPayAmount(for: payAmountInput)
        let receiveAmount = receiveAmountInput.map { AmountInputResult.absolute($0) }

        Swift.swap(&payChainAsset, &receiveChainAsset)
        feeChainAsset = payChainAsset?.chain.utilityChainAsset()
        canPayFeeInPayAsset = false
        fee = nil

        interactor.update(payChainAsset: payChainAsset)
        interactor.update(receiveChainAsset: receiveChainAsset)
        interactor.update(feeChainAsset: feeChainAsset)
        let newFocus: TextFieldFocus?

        switch currentFocus {
        case .payAsset:
            newFocus = .receiveAsset
        case .receiveAsset:
            newFocus = .payAsset
        case .none:
            newFocus = nil
        }

        let previousDirection = quoteArgs?.direction

        switch previousDirection {
        case .sell:
            receiveAmountInput = payAmount
            payAmountInput = nil
            refreshQuote(direction: .buy, forceUpdate: true)
        case .buy:
            payAmountInput = receiveAmount
            receiveAmountInput = nil
            refreshQuote(direction: .sell, forceUpdate: true)
        case .none:
            payAmountInput = nil
            receiveAmountInput = nil
        }

        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        provideSettingsState()
        provideFeeViewModel()
        provideIssues()

        view?.didReceive(focus: newFocus)
    }

    func selectMaxPayAmount() {
        maxCorrectionCounter.resetCounter()

        applySwapMax()
    }

    func showFeeInfo() {
        guard let quote, let fee else {
            return
        }

        wireframe.showFeeDetails(
            from: view,
            operations: quote.metaOperations,
            fee: fee
        )
    }

    func showRateInfo() {
        wireframe.showRateInfo(from: view)
    }

    func showRouteDetails() {
        guard let quote, let fee else {
            return
        }

        wireframe.showRouteDetails(
            from: view,
            quote: quote,
            fee: fee
        )
    }

    func proceed() {
        guard let swapModel = getSwapModel() else {
            return
        }

        let validators = getBaseValidations(for: swapModel, interactor: interactor, locale: selectedLocale)

        DataValidationRunner(validators: validators).runValidation(
            notifyingOnSuccess: { [weak self] in
                self?.view?.didStopLoading()

                guard let slippage = self?.slippage,
                      let quote = self?.quote,
                      let quoteArgs = self?.quoteArgs else {
                    return
                }

                let confirmInitState = SwapConfirmInitState(
                    chainAssetIn: swapModel.payChainAsset,
                    chainAssetOut: swapModel.receiveChainAsset,
                    feeChainAsset: swapModel.feeChainAsset,
                    slippage: slippage,
                    quote: quote,
                    quoteArgs: quoteArgs
                )

                self?.wireframe.showConfirmation(
                    from: self?.view,
                    initState: confirmInitState
                )
            },
            notifyingOnStop: { [weak self] _ in
                self?.view?.didStopLoading()
            }, notifyingOnResume: { [weak self] _ in
                self?.view?.didStartLoading()
            }
        )
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

    func depositInsufficientToken() {
        guard let payChainAsset = payChainAsset else {
            return
        }

        wireframe.showGetTokenOptions(
            form: view,
            purchaseHadler: self,
            destinationChainAsset: payChainAsset,
            locale: selectedLocale
        )
    }
}

extension SwapSetupPresenter: SwapSetupInteractorOutputProtocol {
    func didReceiveCanPayFeeInPayAsset(_ value: Bool, chainAssetId: ChainAssetId) {
        logger.debug("Can pay fee in \(chainAssetId.assetId): \(value)")

        if payChainAsset?.chainAssetId == chainAssetId {
            canPayFeeInPayAsset = value

            switchFeeChainAssetIfNecessary()
            provideFeeViewModel()
        }
    }

    func didReceiveQuoteDataChanged() {
        logger.debug("Requote request received")

        refreshQuote(direction: quoteArgs?.direction ?? .sell, forceUpdate: false)
        estimateFee()
    }
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateViews()
        }
    }
}

extension SwapSetupPresenter: RampFlowManaging, RampDelegate {
    func rampDidComplete(
        action: RampActionType,
        chainAsset _: ChainAsset
    ) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else { return }

            wireframe.presentRampDidComplete(
                view: view,
                action: action,
                locale: selectedLocale
            )
        }
    }
}
