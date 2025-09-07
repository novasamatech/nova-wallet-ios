import Foundation
import BigInt
import Foundation_iOS

final class SwapConfirmPresenter: SwapBasePresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol
    let initState: SwapConfirmInitState
    let slippageBounds: SlippageBounds

    var accountId: AccountId? {
        selectedWallet.fetch(for: initState.chainAssetOut.chain.accountRequest())?.accountId
    }

    private var viewModelFactory: SwapDetailsViewModelFactoryProtocol

    private var quoteArgs: AssetConversion.QuoteArgs

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol,
        initState: SwapConfirmInitState,
        selectedWallet: MetaAccountModel,
        viewModelFactory: SwapDetailsViewModelFactoryProtocol,
        priceDifferenceFactory: SwapPriceDifferenceModelFactoryProtocol,
        priceStore: AssetExchangePriceStoring,
        slippageBounds: SlippageBounds,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.slippageBounds = slippageBounds
        self.initState = initState
        quoteArgs = initState.quoteArgs

        super.init(
            selectedWallet: selectedWallet,
            dataValidatingFactory: dataValidatingFactory,
            priceDiffFactory: priceDifferenceFactory,
            priceStore: priceStore,
            logger: logger
        )

        quoteResult = .success(initState.quote)
        self.localizationManager = localizationManager
    }

    override func getSpendingInputAmount() -> Decimal? {
        quote?.route.amountIn.decimal(precision: initState.chainAssetIn.asset.precision)
    }

    override func getQuoteArgs() -> AssetConversion.QuoteArgs? {
        quoteArgs
    }

    override func getSlippage() -> BigRational {
        initState.slippage
    }

    override func getPayChainAsset() -> ChainAsset? {
        initState.chainAssetIn
    }

    override func getReceiveChainAsset() -> ChainAsset? {
        initState.chainAssetOut
    }

    override func getFeeChainAsset() -> ChainAsset? {
        initState.feeChainAsset
    }

    override func shouldHandleRoute(for _: AssetConversion.QuoteArgs?) -> Bool {
        quoteArgs == quoteArgs
    }

    override func estimateFee() {
        guard let quote else {
            return
        }

        fee = nil
        provideFeeViewModel()

        interactor.calculateFee(
            for: quote.route,
            slippage: initState.slippage,
            feeAsset: initState.feeChainAsset
        )
    }

    override func applySwapMax() {
        let maxAmount = getMaxModel().calculate()

        guard
            maxAmount > 0,
            let maxAmountInPlank = maxAmount.toSubstrateAmount(
                precision: initState.chainAssetIn.assetDisplayInfo.assetPrecision
            ) else {
            return
        }

        quoteArgs = AssetConversion.QuoteArgs(
            assetIn: initState.quoteArgs.assetIn,
            assetOut: initState.quoteArgs.assetOut,
            amount: maxAmountInPlank,
            direction: .sell
        )

        view?.didReceiveStartLoading()

        interactor.calculateQuote(for: quoteArgs)
    }

    override func handleBaseError(_ error: SwapBaseError) {
        handleBaseError(
            error,
            view: view,
            interactor: interactor,
            wireframe: wireframe,
            locale: selectedLocale
        )

        if case .quote = error {
            view?.didReceiveStopLoading()
        }
    }

    override func handleNewQuote(_ quote: AssetExchangeQuote, for _: AssetConversion.QuoteArgs) {
        quoteResult = .success(quote)
        fee = nil

        view?.didReceiveStopLoading()

        updateViews()
        estimateFee()
    }

    override func handleNewFee(
        _: AssetExchangeFee?,
        feeChainAssetId _: ChainAssetId?
    ) {
        provideRouteViewModel()
        provideFeeViewModel()
    }

    override func handleNewPrice(_: PriceData?, priceId: AssetModel.PriceId) {
        if initState.chainAssetIn.asset.priceId == priceId {
            provideAssetInViewModel()
            providePriceDifferenceViewModel()
        }

        if initState.chainAssetOut.asset.priceId == priceId {
            provideAssetOutViewModel()
            providePriceDifferenceViewModel()
        }

        if initState.feeChainAsset.asset.priceId == priceId {
            provideFeeViewModel()
        }
    }
}

extension SwapConfirmPresenter {
    private func provideAssetInViewModel() {
        guard let quote else {
            return
        }

        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: initState.chainAssetIn,
            amount: quote.route.amountIn,
            priceData: payAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    private func provideAssetOutViewModel() {
        guard let quote else {
            return
        }
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: initState.chainAssetOut,
            amount: quote.route.amountOut,
            priceData: receiveAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAssetOut(viewModel: viewModel)
    }

    private func provideRateViewModel() {
        guard let quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: quote.route.amountIn,
            amountOut: quote.route.amountOut
        )
        let viewModel = viewModelFactory.rateViewModel(from: params, locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: viewModel))
    }

    private func provideRouteViewModel() {
        guard let quote, fee != nil else {
            view?.didReceiveRoute(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.routeViewModel(from: quote.metaOperations)

        view?.didReceiveRoute(viewModel: .loaded(value: viewModel))
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

    private func providePriceDifferenceViewModel() {
        guard let quote else {
            view?.didReceivePriceDifference(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: quote.route.amountIn,
            amountOut: quote.route.amountOut
        )

        if let viewModel = viewModelFactory.priceDifferenceViewModel(
            rateParams: params,
            priceIn: payAssetPriceData,
            priceOut: receiveAssetPriceData,
            locale: selectedLocale
        ) {
            view?.didReceivePriceDifference(viewModel: .loaded(value: viewModel))
        } else {
            view?.didReceivePriceDifference(viewModel: nil)
        }
    }

    private func provideSlippageViewModel() {
        let viewModel = viewModelFactory.slippageViewModel(slippage: initState.slippage, locale: selectedLocale)
        view?.didReceiveSlippage(viewModel: viewModel)
        let warning = slippageBounds.warning(for: initState.slippage.decimalValue, locale: selectedLocale)
        view?.didReceiveWarning(viewModel: warning)
    }

    private func provideFeeViewModel() {
        guard
            let operations = quote?.metaOperations,
            let fee = fee?.calculateTotalFeeInFiat(matching: operations, priceStore: priceStore) else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.feeViewModel(
            amountInFiat: fee,
            isEditable: false,
            currencyId: feeAssetPriceData?.currencyId,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func provideWalletViewModel() {
        guard let chainAccountResponse = selectedWallet.fetchMetaChainAccount(
            for: initState.chainAssetOut.chain.accountRequest()
        ) else {
            return
        }

        let viewModel = viewModelFactory.walletViewModel(metaAccountResponse: chainAccountResponse)

        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func updateViews() {
        provideAssetInViewModel()
        provideAssetOutViewModel()
        provideRateViewModel()
        provideRouteViewModel()
        provideExecutionTimeViewModel()
        providePriceDifferenceViewModel()
        provideSlippageViewModel()
        provideFeeViewModel()
        provideWalletViewModel()
    }

    private func submit() {
        guard let fee, let quote else {
            return
        }

        let executionModel = SwapExecutionModel(
            chainAssetIn: initState.chainAssetIn,
            chainAssetOut: initState.chainAssetOut,
            feeAsset: initState.feeChainAsset,
            quote: quote,
            fee: fee
        )

        view?.didReceiveStartLoading()

        interactor.initiateSwapSubmission(of: executionModel)
    }
}

extension SwapConfirmPresenter: SwapConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
        estimateFee()
        updateViews()
    }

    func showRateInfo() {
        wireframe.showRateInfo(from: view)
    }

    func showPriceDifferenceInfo() {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.swapsSetupPriceDifference()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.swapsSetupPriceDifferenceDescription()
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showSlippageInfo() {
        wireframe.showSlippageInfo(from: view)
    }

    func showNetworkFeeInfo() {
        guard let fee, let quote else {
            return
        }

        wireframe.showFeeDetails(
            from: view,
            operations: quote.metaOperations,
            fee: fee
        )
    }

    func showAddressOptions() {
        guard let view = view else {
            return
        }

        guard let address = try? accountId?.toAddress(using: initState.chainAssetOut.chain.chainFormat) else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: initState.chainAssetIn.chain,
            locale: selectedLocale
        )
    }

    func showRouteDetails() {
        guard let fee, let quote else {
            return
        }

        wireframe.showRouteDetails(
            from: view,
            quote: quote,
            fee: fee
        )
    }

    func confirm() {
        guard let swapModel = getSwapModel() else {
            return
        }

        let validators = getBaseValidations(
            for: swapModel,
            interactor: interactor,
            locale: selectedLocale
        )

        DataValidationRunner(validators: validators).runValidation(
            notifyingOnSuccess: { [weak self] in
                self?.submit()
            },
            notifyingOnStop: { [weak self] _ in
                self?.view?.didReceiveStopLoading()
            },
            notifyingOnResume: { [weak self] _ in
                self?.view?.didReceiveStartLoading()
            }
        )
    }
}

extension SwapConfirmPresenter: SwapConfirmInteractorOutProtocol {
    func didCompleteSwapSubmission(with result: Result<ExtrinsicSubmittedModel, Error>) {
        switch result {
        case let .success(model):
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: .dismiss,
                locale: selectedLocale
            )
        case let .failure(error):
            view?.didReceiveStopLoading()

            logger.error("Swap failed: \(error)")

            _ = wireframe.handleExtrinsicSigningErrorPresentation(
                error,
                view: view,
                closeAction: .dismissAllModals,
                completionClosure: nil
            )
        }
    }

    func didDecideMonitoredExecution(for model: SwapExecutionModel) {
        wireframe.showSwapExecution(from: view, model: model)
    }
}

extension SwapConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateViews()
        }
    }
}
