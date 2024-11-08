import Foundation
import SoraFoundation
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
    private var isManualFeeSet: Bool = false

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
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
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
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    // MARK: Base implementation

    override func getSpendingInputAmount() -> Decimal? {
        guard let payAmountInput = payAmountInput else {
            return nil
        }

        let maxAmount = getMaxModel()?.calculate() ?? 0
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
        guard let route = route else {
            return
        }

        fee = nil
        provideFeeViewModel()
        provideNotification()

        interactor.calculateFee(for: route, slippage: slippage)
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

    override func handleNewRoute(_ route: AssetExchangeRoute, for quoteArgs: AssetConversion.QuoteArgs) {
        logger.debug("New quote: \(route)")

        switch quoteArgs.direction {
        case .buy:
            let payAmount = payChainAsset.map {
                route.quote.decimal(assetInfo: $0.asset.displayInfo)
            }

            payAmountInput = payAmount.map { .absolute($0) }
            providePayAmountInputViewModel()
            providePayInputPriceViewModel()
            provideReceiveInputPriceViewModel()
        case .sell:
            receiveAmountInput = receiveChainAsset.map {
                route.quote.decimal(assetInfo: $0.asset.displayInfo)
            }

            provideReceiveAmountInputViewModel()
            provideReceiveInputPriceViewModel()
            providePayInputPriceViewModel()
        }

        provideRateViewModel()
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
        provideNotification()
        switchFeeChainAssetIfNecessary()
    }

    override func handleNewPrice(_: PriceData?, chainAssetId: ChainAssetId) {
        if payChainAsset?.chainAssetId == chainAssetId {
            providePayInputPriceViewModel()
        }

        if receiveChainAsset?.chainAssetId == chainAssetId {
            provideReceiveInputPriceViewModel()
        }

        if feeChainAsset?.chainAssetId == chainAssetId {
            provideFeeViewModel()
        }

        provideNotification()
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

        let maxAmount = getMaxModel()?.calculate()
        return input.absoluteValue(from: maxAmount ?? 0)
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
            quoteResult: quoteResult
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
        if let route = route, let payAssetDisplayInfo = payChainAsset?.assetDisplayInfo {
            let params = RateParams(
                assetDisplayInfoIn: payAssetDisplayInfo,
                assetDisplayInfoOut: assetDisplayInfo,
                amountIn: route.amountIn,
                amountOut: route.amountOut
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
            let route = route else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }
        let rateViewModel = viewModelFactory.rateViewModel(
            from: .init(
                assetDisplayInfoIn: assetDisplayInfoIn,
                assetDisplayInfoOut: assetDisplayInfoOut,
                amountIn: route.amountIn,
                amountOut: route.amountOut
            ),
            locale: selectedLocale
        )

        view?.didReceiveRate(viewModel: .loaded(value: rateViewModel))
    }

    private func provideFeeViewModel() {
        guard quoteArgs != nil, let feeChainAsset = feeChainAsset else {
            return
        }
        guard let fee = fee?.networkFee.targetAmount else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let isEditable = (payChainAsset?.isUtilityAsset == false) && canPayFeeInPayAsset
        let viewModel = viewModelFactory.feeViewModel(
            amount: fee,
            assetDisplayInfo: feeChainAsset.assetDisplayInfo,
            isEditable: isEditable,
            priceData: feeAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func provideIssues() {
        let issues = viewModelFactory.detectIssues(in: getIssueParams(), locale: selectedLocale)
        view?.didReceive(issues: issues)
    }

    private func provideNotification() {
        guard
            let networkFeeAddition = fee?.networkNativeFeeAddition,
            let feeChainAsset = feeChainAsset,
            !feeChainAsset.isUtilityAsset,
            let utilityChainAsset = feeChainAsset.chain.utilityChainAsset() else {
            view?.didSetNotification(message: nil)
            return
        }

        let message = viewModelFactory.minimalBalanceSwapForFeeMessage(
            for: networkFeeAddition,
            feeChainAsset: feeChainAsset,
            utilityChainAsset: utilityChainAsset,
            utilityPriceData: prices[utilityChainAsset.chainAssetId],
            locale: selectedLocale
        )

        view?.didSetNotification(message: message)
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
                provideNotification()
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
                provideNotification()
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
        provideNotification()

        estimateFee()
    }

    private func updateViews() {
        providePayAssetViews()
        provideReceiveAssetViews()
        provideDetailsViewModel()
        provideButtonState()
        provideSettingsState()
        provideIssues()
        provideNotification()
    }

    private func switchFeeChainAssetIfNecessary() {
        guard
            canPayFeeInPayAsset,
            !isManualFeeSet,
            let payChainAsset = getPayChainAsset(),
            !payChainAsset.isUtilityAsset,
            let feeChainAsset = getFeeChainAsset(),
            feeChainAsset.isUtilityAsset,
            let feeAssetBalance = feeAssetBalance,
            let payAssetBalance = payAssetBalance,
            payAssetBalance.transferable > 0,
            let fee = fee?.totalFee.nativeAmount,
            let nativeMinBalance = utilityAssetBalanceExistense?.minBalance else {
            return
        }

        if feeAssetBalance.freeInPlank < fee + nativeMinBalance {
            updateFeeChainAsset(payChainAsset)
        }
    }
}

extension SwapSetupPresenter: SwapSetupPresenterProtocol {
    func setup() {
        updateViews()

        interactor.setup()
        interactor.update(payChainAsset: payChainAsset)
        interactor.update(feeChainAsset: feeChainAsset)

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
            let feeChainAsset = chainAsset.chain.utilityAsset().map {
                ChainAsset(chain: chainAsset.chain, asset: $0)
            }

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
            self?.isManualFeeSet = false

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
        provideNotification()
    }

    func updateReceiveAmount(_ amount: Decimal?) {
        receiveAmountInput = amount
        refreshQuote(direction: .buy)
        provideReceiveInputPriceViewModel()
        providePayInputPriceViewModel()
        provideButtonState()
        provideIssues()
        provideNotification()
    }

    func flip(currentFocus: TextFieldFocus?) {
        let payAmount = getPayAmount(for: payAmountInput)
        let receiveAmount = receiveAmountInput.map { AmountInputResult.absolute($0) }

        Swift.swap(&payChainAsset, &receiveChainAsset)
        feeChainAsset = payChainAsset?.chain.utilityChainAsset()
        canPayFeeInPayAsset = false

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

    func showFeeActions() {
        guard
            let payChainAsset = payChainAsset,
            let utilityAsset = payChainAsset.chain.utilityChainAsset()
        else {
            return
        }

        wireframe.showFeeAssetSelection(
            from: view,
            utilityAsset: utilityAsset,
            sendingAsset: payChainAsset,
            currentFeeAsset: feeChainAsset,
            onFeeAssetSelect: { [weak self] selectedAsset in
                if selectedAsset.chainAssetId != self?.feeChainAsset?.chainAssetId {
                    self?.isManualFeeSet = true
                }
                self?.updateFeeChainAsset(selectedAsset)
            }
        )
    }

    func showFeeInfo() {
        wireframe.showFeeInfo(from: view)
    }

    func showRateInfo() {
        wireframe.showRateInfo(from: view)
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
                      let route = self?.route,
                      let quoteArgs = self?.quoteArgs else {
                    return
                }

                let confirmInitState = SwapConfirmInitState(
                    chainAssetIn: swapModel.payChainAsset,
                    chainAssetOut: swapModel.receiveChainAsset,
                    feeChainAsset: swapModel.feeChainAsset,
                    slippage: slippage,
                    route: route,
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
    func didReceive(setupError: SwapSetupError) {
        logger.error("Did receive setup error: \(setupError)")

        switch setupError {
        case .payAssetSetFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                if let payChainAsset = self?.payChainAsset {
                    self?.interactor.update(payChainAsset: payChainAsset)
                }
            }
        case .remoteSubscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryRemoteSubscription()
            }
        }
    }

    func didReceiveCanPayFeeInPayAsset(_ value: Bool, chainAssetId: ChainAssetId) {
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

extension SwapSetupPresenter: PurchaseFlowManaging, PurchaseDelegate, ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let actions = context as? [PurchaseAction] else {
            return
        }

        startPuchaseFlow(
            from: view,
            purchaseAction: actions[index],
            wireframe: wireframe,
            locale: selectedLocale
        )
    }

    func purchaseDidComplete() {
        wireframe.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}
