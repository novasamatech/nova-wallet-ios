import Foundation
import Foundation_iOS
import BigInt
import NovaAnalytics

final class SwapSetupPresenter: SwapBasePresenter {
    weak var view: SwapSetupViewProtocol?
    let wireframe: SwapSetupWireframeProtocol
    let interactor: SwapSetupInteractorInputProtocol
    let initState: SwapSetupInitState
    var source: SwapSource
    let placement: SwapSetupPlacement
    let abandonTracker = AnalyticsAbandonTracker {
        AnalyticsEvent.swapAbandoned(stage: .setup)
    }

    private(set) var viewModelFactory: SwapsSetupViewModelFactoryProtocol

    weak var assetPriceChartModule: AssetPriceChartModuleInputProtocol?
    var chartContext = SwapPriceChartContext()
    var quoteFailureAlertState = SwapQuoteFailureAlertState.armed
    var refreshOrigin = SwapRefreshOrigin.user

    private(set) var quoteArgs: AssetConversion.QuoteArgs? {
        didSet {
            provideDetailsViewModel()
            provideQuoteState()
        }
    }

    override var quoteResult: Result<AssetExchangeQuote, Error>? {
        didSet {
            updateRefreshOrigin(replacing: oldValue)
            provideQuoteState()
            provideMinReceivedViewModel()
        }
    }

    private var payAmountInput: AmountInputResult?
    private var receiveAmountInput: Decimal?

    private var canPayFeeInPayAsset: Bool = false
    private var payChainAsset: ChainAsset?
    private var receiveChainAsset: ChainAsset?
    private var feeChainAsset: ChainAsset?

    private(set) var isFeePending = false
    private var wasShowingInsufficientBalance = false

    private(set) var slippage: BigRational
    let slippageBounds: SlippageBounds

    private var detailsAvailable: Bool {
        !quoteResult.hasError() && quoteArgs != nil
    }

    /*
     *  We might have cases when quote recalcution triggers fee recalculation and vice versa
     *  and we want to bound such triggers to avoid deadlock.
     */
    private var maxCorrectionCounter = MaxCounter.feeCorrection()

    var poolLimitCorrectionCounter = MaxCounter.feeCorrection()

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
        source: SwapSource,
        placement: SwapSetupPlacement,
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
        slippageBounds = SlippageBounds(config: slippageConfig)

        self.source = source
        self.placement = placement

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
        isFeePending = true
        provideFeeViewModel()
        provideCommissionDisclosureViewModel()
        updateReceiveAmountFromQuote()
        provideButtonState()

        interactor.calculateFee(for: quote.route, slippage: slippage, feeAsset: feeChainAsset)
    }

    override func applySwapMax() {
        payAmountInput = .rate(1)
        providePayAssetViews()
        refreshQuote(direction: .sell)
        armQuoteFailureAlert()
        provideButtonState()
        provideIssues()
    }

    override func canApplyPoolTradeLimit() -> Bool {
        poolLimitCorrectionCounter.hasBudget()
    }

    override func resetPoolTradeLimitCorrection() {
        poolLimitCorrectionCounter.resetCounter()
    }

    override func applyPoolTradeLimit(amount: Balance, direction: AssetConversion.Direction) {
        applySuggestedAmount(amount, direction: direction)
    }

    override func handleBaseError(_ error: SwapBaseError) {
        if case .fetchFeeFailed = error {
            isFeePending = false
            markBackgroundRefresh()
        }

        handleBaseError(
            error,
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            locale: selectedLocale
        )

        provideIssues()
        provideButtonState()
        provideDetailsViewModel()

        provideCommissionDisclosureViewModel()
        startQuoteFailureEpisodeIfNeeded(for: error)
    }

    override func handleNewQuote(_ quote: AssetExchangeQuote, for quoteArgs: AssetConversion.QuoteArgs) {
        logger.debug("New quote: \(quote)")

        armQuoteFailureAlert()

        if let fee, !quote.hasSamePath(other: fee.route) {
            maxCorrectionCounter.resetCounter()
        }

        // we need to keep fee in sync with quote
        fee = nil

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
            updateReceiveAmountFromQuote()
            providePayInputPriceViewModel()
        }

        provideRateViewModel()
        provideCommissionDisclosureViewModel()
        provideRouteViewModel()
        provideExecutionTimeViewModel()
        provideDetailsViewModel()
        estimateFee()
        provideIssues()
        provideButtonState()
    }

    override func handleNewFee(
        _: AssetExchangeFee?,
        feeChainAssetId _: ChainAssetId?
    ) {
        isFeePending = false
        provideFeeViewModel()
        provideCommissionDisclosureViewModel()
        updateReceiveAmountFromQuote()
        provideRateViewModel()

        if case .rate = payAmountInput {
            providePayAmountInputViewModel()
            providePayInputPriceViewModel()

            let correctionDirection = quoteArgs?.direction ?? .sell

            /*
             * As fee changes the max amount we might also refresh the quote but make sure
             * no deadlock.
             */
            if
                !isMaxCorrectionConverged(for: correctionDirection),
                maxCorrectionCounter.incrementCounterIfPossible() {
                refreshQuote(direction: correctionDirection, forceUpdate: false)
                armQuoteFailureAlert()
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
        markBackgroundRefresh()
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
        if receiveChainAsset?.chainAssetId == chainAsset {
            provideReceiveTitle()
        }

        if payChainAsset?.chainAssetId == chainAsset {
            providePayTitle()

            if case .rate = payAmountInput {
                providePayInputPriceViewModel()
                providePayAmountInputViewModel()
            }
        }

        provideIssues()
        provideButtonState()
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

    override func handleNewCollateralLimit(for chainAssetId: ChainAssetId) {
        guard payChainAsset?.chainAssetId == chainAssetId else {
            return
        }

        handleNewBalance(payAssetBalance, for: chainAssetId)
        provideButtonState()

        if case .rate = payAmountInput {
            refreshQuote(direction: .sell, forceUpdate: false)
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

    private func isMaxCorrectionConverged(for direction: AssetConversion.Direction) -> Bool {
        guard
            direction == .sell,
            let payChainAsset,
            let payInPlank = getPayAmount(for: payAmountInput)?.toSubstrateAmount(
                precision: Int16(payChainAsset.assetDisplayInfo.assetPrecision)
            ) else {
            return false
        }

        return payInPlank == quoteArgs?.amount
    }

    func getIssueParams() -> SwapIssueCheckParams {
        .init(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            payAmount: isPayAmountHidden ? nil : getSpendingInputAmount(),
            receiveAmount: isReceiveAmountHidden ? nil : receiveAmountInput,
            payAssetBalance: payAssetBalance,
            receiveAssetBalance: receiveAssetBalance,
            payAssetExistense: payAssetBalanceExistense,
            receiveAssetExistense: receiveAssetBalanceExistense,
            quoteResult: quoteResult,
            fee: fee,
            isFeePending: isFeePending && quote != nil,
            refreshOrigin: refreshOrigin,
            isPayAmountHidden: isPayAmountHidden,
            wasShowingInsufficientBalance: wasShowingInsufficientBalance
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

    func provideReceiveTitle() {
        let receiveTitleViewModel = viewModelFactory.receiveTitleViewModel(
            assetDisplayInfo: receiveChainAsset?.assetDisplayInfo,
            balance: receiveAssetBalance?.transferable,
            locale: selectedLocale
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
                amountOut: grossAmountOut
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

    func providePayAssetViews() {
        providePayTitle()
        providePayAssetViewModel()
        providePayInputPriceViewModel()
        providePayAmountInputViewModel()
    }

    private func updateReceiveAmountFromQuote() {
        guard
            quote != nil,
            let receiveChainAsset,
            quoteArgs?.direction == .sell else {
            return
        }

        receiveAmountInput = netAmountOut.decimal(assetInfo: receiveChainAsset.asset.displayInfo)

        provideReceiveAmountInputViewModel()
        provideReceiveInputPriceViewModel()
    }

    func provideReceiveAssetViews() {
        provideReceiveTitle()
        provideReceiveAssetViewModel()
        provideReceiveInputPriceViewModel()
        provideReceiveAmountInputViewModel()
    }

    func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            for: getIssueParams(),
            locale: selectedLocale
        )

        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled && !isPayAssetCollateralLimitPending
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
                amountOut: netAmountOut
            ),
            locale: selectedLocale
        )

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }

    func provideIssues() {
        let issues = viewModelFactory.detectIssues(in: getIssueParams(), locale: selectedLocale)
        wasShowingInsufficientBalance = issues.contains(.insufficientBalance)
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
        provideCommissionDisclosureViewModel()
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
        provideCommissionDisclosureViewModel()

        estimateFee()
    }

    func updateViews() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel()
        provideButtonState()
        provideSettingsState()
        provideIssues()
        provideCommissionDisclosureViewModel()
        provideFormViewModels()
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

    private func clearCounterpartIfNeeded(for result: SwapTokenSelectionResult, pickedSide: SwapTokenSelectionSide) {
        guard result.clearsCounterpart else {
            return
        }

        switch pickedSide {
        case .pay:
            receiveChainAsset = nil
            interactor.update(receiveChainAsset: nil)
        case .receive:
            payChainAsset = nil
            feeChainAsset = nil
            interactor.update(payChainAsset: nil)
            interactor.update(feeChainAsset: nil)
        }

        payAmountInput = nil
        receiveAmountInput = nil
        quoteArgs = nil
        quoteResult = nil
        fee = nil
        updateViews()
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        trackScreenOpened()

        updateViews()

        interactor.setup()
        interactor.update(payChainAsset: payChainAsset)
        interactor.update(feeChainAsset: feeChainAsset)
        interactor.update(receiveChainAsset: receiveChainAsset)

        provideChartAsset()

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

        provideInitialFocus()
    }

    func selectPayToken() {
        let context = SwapTokenSelectionContext(current: payChainAsset, counterpart: receiveChainAsset)
        wireframe.showPayTokenSelection(from: view, context: context) { [weak self] result in
            self?.clearCounterpartIfNeeded(for: result, pickedSide: .pay)
            let chainAsset = result.chainAsset
            self?.payChainAsset = chainAsset
            let feeChainAsset = chainAsset.chain.utilityChainAsset()

            self?.feeChainAsset = feeChainAsset
            self?.fee = nil
            self?.quoteResult = nil
            self?.canPayFeeInPayAsset = false

            self?.providePayAssetViews()
            self?.provideButtonState()
            self?.provideSettingsState()
            self?.provideFeeViewModel()
            self?.provideIssues()
            self?.provideChartAsset()

            self?.interactor.update(payChainAsset: chainAsset)
            self?.interactor.update(feeChainAsset: feeChainAsset)

            if let direction = self?.quoteArgs?.direction {
                self?.refreshQuote(direction: direction, forceUpdate: false)
            } else if self?.payAmountInput != nil {
                self?.refreshQuote(direction: .sell, forceUpdate: false)
            } else {
                self?.refreshQuote(direction: .buy, forceUpdate: false)
            }

            self?.armQuoteFailureAlert()
            self?.endRetryAttemptIfPairChanged()
        }
    }

    func selectReceiveToken() {
        let context = SwapTokenSelectionContext(current: receiveChainAsset, counterpart: payChainAsset)
        wireframe.showReceiveTokenSelection(from: view, context: context) { [weak self] result in
            self?.clearCounterpartIfNeeded(for: result, pickedSide: .receive)
            let chainAsset = result.chainAsset
            self?.receiveChainAsset = chainAsset
            self?.quoteResult = nil
            self?.provideReceiveAssetViews()
            self?.provideButtonState()
            self?.provideIssues()
            self?.provideChartAsset()

            self?.interactor.update(receiveChainAsset: chainAsset)

            if let direction = self?.quoteArgs?.direction {
                self?.refreshQuote(direction: direction, forceUpdate: false)
            } else if self?.receiveAmountInput != nil {
                self?.refreshQuote(direction: .buy, forceUpdate: false)
            } else {
                self?.refreshQuote(direction: .sell, forceUpdate: false)
            }

            self?.armQuoteFailureAlert()
            self?.endRetryAttemptIfPairChanged()
        }
    }

    func updatePayAmount(_ amount: Decimal?) {
        payAmountInput = amount.map { .absolute($0) }
        refreshQuote(direction: .sell)
        armQuoteFailureAlert()
        providePayInputPriceViewModel()
        provideReceiveInputPriceViewModel()
        provideButtonState()
        provideIssues()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        refreshQuote(direction: .buy)
        armQuoteFailureAlert()
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

        armQuoteFailureAlert()
        endRetryAttemptIfPairChanged()

        providePayAssetViews()
        provideReceiveAssetViews()
        provideButtonState()
        provideSettingsState()
        provideFeeViewModel()
        provideIssues()
        provideChartAsset()

        view?.didReceive(focus: newFocus)
    }

    func selectMaxPayAmount() {
        maxCorrectionCounter.resetCounter()

        applySwapMax()
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
            self?.provideSlippageViewModel()
            self?.provideMinReceivedViewModel()
            self?.markBackgroundRefresh()
            self?.estimateFee()
        }
    }

    func depositInsufficientToken() {
        guard let payChainAsset = payChainAsset else {
            return
        }

        wireframe.showGetTokenOptions(
            from: view,
            purchaseHandler: self,
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

        markBackgroundRefresh()
        refreshQuote(direction: quoteArgs?.direction ?? .sell, forceUpdate: false)
        estimateFee()
    }
}
