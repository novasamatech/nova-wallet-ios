import Foundation
import BigInt
import SoraFoundation

final class SwapConfirmPresenter: SwapBasePresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol
    let initState: SwapConfirmInitState
    let slippageBounds: SlippageBounds

    var accountId: AccountId? {
        selectedWallet.fetch(for: initState.chainAssetOut.chain.accountRequest())?.accountId
    }

    private var viewModelFactory: SwapConfirmViewModelFactoryProtocol

    private var quoteArgs: AssetConversion.QuoteArgs

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol,
        initState: SwapConfirmInitState,
        selectedWallet: MetaAccountModel,
        viewModelFactory: SwapConfirmViewModelFactoryProtocol,
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
            logger: logger
        )

        quoteResult = .success(initState.quote)
        self.localizationManager = localizationManager
    }

    override func getSpendingInputAmount() -> Decimal? {
        quote?.amountIn.decimal(precision: initState.chainAssetIn.asset.precision)
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

    override func shouldHandleQuote(for quoteArgs: AssetConversion.QuoteArgs?) -> Bool {
        self.quoteArgs == quoteArgs
    }

    override func shouldHandleFee(for _: TransactionFeeId, feeChainAssetId _: ChainAssetId?) -> Bool {
        true
    }

    override func estimateFee() {
        guard let quote = quote,
              let accountId = selectedWallet.fetch(
                  for: initState.chainAssetOut.chain.accountRequest()
              )?.accountId else {
            return
        }

        fee = nil
        provideFeeViewModel()

        interactor.calculateFee(
            args: .init(
                assetIn: quote.assetIn,
                amountIn: quote.amountIn,
                assetOut: quote.assetOut,
                amountOut: quote.amountOut,
                receiver: accountId,
                direction: quoteArgs.direction,
                slippage: initState.slippage
            )
        )
    }

    override func applySwapMax() {
        guard
            let maxAmount = getMaxModel()?.calculate(),
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

    override func handleNewQuote(_ quote: AssetConversion.Quote, for _: AssetConversion.QuoteArgs) {
        quoteResult = .success(quote)

        updateViews()
        estimateFee()
    }

    override func handleNewFee(
        _: AssetConversion.FeeModel?,
        transactionFeeId _: TransactionFeeId,
        feeChainAssetId _: ChainAssetId?
    ) {
        provideFeeViewModel()
        provideNotificationViewModel()
    }

    override func handleNewPrice(_: PriceData?, chainAssetId: ChainAssetId) {
        if initState.chainAssetIn.chainAssetId == chainAssetId {
            provideAssetInViewModel()
            providePriceDifferenceViewModel()
        }

        if initState.chainAssetOut.chainAssetId == chainAssetId {
            provideAssetOutViewModel()
            providePriceDifferenceViewModel()
        }

        if initState.feeChainAsset.chainAssetId == chainAssetId {
            provideFeeViewModel()
        }
    }
}

extension SwapConfirmPresenter {
    private func provideAssetInViewModel() {
        guard let quote = quote else {
            return
        }

        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: initState.chainAssetIn,
            amount: quote.amountIn,
            priceData: payAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    private func provideAssetOutViewModel() {
        guard let quote = quote else {
            return
        }
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: initState.chainAssetOut,
            amount: quote.amountOut,
            priceData: receiveAssetPriceData,
            locale: selectedLocale
        )
        view?.didReceiveAssetOut(viewModel: viewModel)
    }

    private func provideRateViewModel() {
        guard let quote = quote else {
            view?.didReceiveRate(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        )
        let viewModel = viewModelFactory.rateViewModel(from: params, locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: viewModel))
    }

    private func providePriceDifferenceViewModel() {
        guard let quote = quote else {
            view?.didReceivePriceDifference(viewModel: .loading)
            return
        }

        let params = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
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

    private func provideNotificationViewModel() {
        guard
            let networkFeeAddition = fee?.networkNativeFeeAddition,
            !initState.feeChainAsset.isUtilityAsset,
            let utilityChainAsset = initState.feeChainAsset.chain.utilityChainAsset() else {
            view?.didReceiveNotification(viewModel: nil)
            return
        }

        let message = viewModelFactory.minimalBalanceSwapForFeeMessage(
            for: networkFeeAddition,
            feeChainAsset: initState.feeChainAsset,
            utilityChainAsset: utilityChainAsset,
            utilityPriceData: prices[utilityChainAsset.chainAssetId],
            locale: selectedLocale
        )

        view?.didReceiveNotification(viewModel: message)
    }

    private func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.feeViewModel(
            fee: fee.networkFee.targetAmount,
            chainAsset: initState.feeChainAsset,
            priceData: feeAssetPriceData,
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

        guard let walletAddress = WalletDisplayAddress(response: chainAccountResponse) else {
            view?.didReceiveWallet(viewModel: nil)
            return
        }
        let viewModel = viewModelFactory.walletViewModel(walletAddress: walletAddress)

        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func updateViews() {
        provideAssetInViewModel()
        provideAssetOutViewModel()
        provideRateViewModel()
        providePriceDifferenceViewModel()
        provideSlippageViewModel()
        provideNotificationViewModel()
        provideFeeViewModel()
        provideWalletViewModel()
    }

    private func submit() {
        guard let quote = quote, let accountId = accountId else {
            return
        }

        let args = AssetConversion.CallArgs(
            assetIn: quote.assetIn,
            amountIn: quote.amountIn,
            assetOut: quote.assetOut,
            amountOut: quote.amountOut,
            receiver: accountId,
            direction: initState.quoteArgs.direction,
            slippage: initState.slippage
        )

        view?.didReceiveStartLoading()

        interactor.submit(args: args, lastFee: fee?.networkFee.targetAmount)
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
            R.string.localizable.swapsSetupPriceDifference(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsSetupPriceDifferenceDescription(
                preferredLanguages: $0.rLanguages
            )
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
        wireframe.showFeeInfo(from: view)
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

extension SwapConfirmPresenter: SwapConfirmInteractorOutputProtocol {
    func didReceive(error: SwapConfirmError) {
        view?.didReceiveStopLoading()
        switch error {
        case let .submit(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveConfirmation(hash _: String) {
        view?.didReceiveStopLoading()

        guard let payChainAsset = getPayChainAsset() else {
            return
        }
        wireframe.complete(
            on: view,
            payChainAsset: payChainAsset,
            locale: selectedLocale
        )
    }
}

extension SwapConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateViews()
        }
    }
}
