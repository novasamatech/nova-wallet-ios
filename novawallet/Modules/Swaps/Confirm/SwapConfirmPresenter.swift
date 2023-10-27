import Foundation
import BigInt
import SoraFoundation

final class SwapConfirmPresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol
    let dataValidatingFactory: SwapDataValidatorFactoryProtocol
    let initState: SwapConfirmInitState
    let slippageBounds = SlippageBounds()

    private var viewModelFactory: SwapConfirmViewModelFactoryProtocol
    private var feePriceData: PriceData?
    private var chainAssetInPriceData: PriceData?
    private var chainAssetOutPriceData: PriceData?
    private var quote: AssetConversion.Quote?
    private var fee: BigUInt?
    private var payAccountId: AccountId?
    private var chainAccountResponse: MetaChainAccountResponse
    private var balances: [ChainAssetId: AssetBalance?] = [:]

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol,
        viewModelFactory: SwapConfirmViewModelFactoryProtocol,
        chainAccountResponse: MetaChainAccountResponse,
        localizationManager: LocalizationManagerProtocol,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        initState: SwapConfirmInitState
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.initState = initState
        quote = initState.quote
        self.chainAccountResponse = chainAccountResponse
        self.dataValidatingFactory = dataValidatingFactory
        self.localizationManager = localizationManager
    }

    private func provideAssetInViewModel() {
        guard let quote = quote else {
            return
        }
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: initState.chainAssetIn,
            amount: quote.amountIn,
            priceData: chainAssetInPriceData
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
            priceData: chainAssetOutPriceData
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
        let viewModel = viewModelFactory.rateViewModel(from: params)

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
            priceIn: chainAssetInPriceData,
            priceOut: chainAssetOutPriceData
        ) {
            view?.didReceivePriceDifference(viewModel: .loaded(value: viewModel))
        } else {
            view?.didReceivePriceDifference(viewModel: nil)
        }
    }

    private func provideSlippageViewModel() {
        let viewModel = viewModelFactory.slippageViewModel(slippage: initState.slippage)
        view?.didReceiveSlippage(viewModel: viewModel)
        let warning = slippageBounds.warning(
            for: initState.slippage.toPercents().decimalValue,
            locale: selectedLocale
        )
        view?.didReceiveWarning(viewModel: warning)
    }

    private func provideFeeViewModel() {
        guard let fee = fee else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }
        let viewModel = viewModelFactory.feeViewModel(
            fee: fee,
            chainAsset: initState.feeChainAsset,
            priceData: feePriceData
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func provideWalletViewModel() {
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
        provideFeeViewModel()
        provideWalletViewModel()
    }

    private func estimateFee() {
        guard let quote = quote,
              let accountId = payAccountId else {
            return
        }

        fee = nil
        provideFeeViewModel()

        interactor.calculateFee(args: .init(
            assetIn: quote.assetIn,
            amountIn: quote.amountIn,
            assetOut: quote.assetOut,
            amountOut: quote.amountOut,
            receiver: accountId,
            direction: initState.quoteArgs.direction,
            slippage: initState.slippage
        )
        )
    }

    private func validators(
        spendingAmount: Decimal?
    ) -> [DataValidating] {
        let feeDecimal = fee.map { Decimal.fromSubstrateAmount(
            $0,
            precision: Int16(initState.feeChainAsset.asset.precision)
        ) } ?? nil

        let payAssetBalance = balances[initState.chainAssetIn.chainAssetId]

        let validators: [DataValidating] = [
            dataValidatingFactory.has(fee: feeDecimal, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            },
            dataValidatingFactory.canSpendAmountInPlank(
                balance: payAssetBalance??.transferable,
                spendingAmount: spendingAmount,
                asset: initState.chainAssetIn.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: payAssetBalance??.transferable,
                fee: initState.chainAssetIn.chainAssetId == initState.feeChainAsset.chainAssetId ? fee : nil,
                spendingAmount: spendingAmount,
                asset: initState.feeChainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.has(
                quote: quote,
                payChainAssetId: initState.chainAssetIn.chainAssetId,
                receiveChainAssetId: initState.chainAssetOut.chainAssetId,
                locale: selectedLocale,
                onError: { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.interactor.calculateQuote(for: self.initState.quoteArgs)
                }
            )
        ]

        return validators
    }

    private func submit() {
        guard let quote = quote,
              let accountId = payAccountId else {
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

        interactor.submit(args: args)
    }

    private func checkRateChanged(
        oldValue: AssetConversion.Quote,
        newValue: AssetConversion.Quote,
        confirmClosure: @escaping () -> Void
    ) {
        guard oldValue != newValue else {
            confirmClosure()
            return
        }
        let oldRateParams = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: oldValue.amountIn,
            amountOut: oldValue.amountOut
        )
        let newRateParams = RateParams(
            assetDisplayInfoIn: initState.chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: initState.chainAssetOut.assetDisplayInfo,
            amountIn: newValue.amountIn,
            amountOut: newValue.amountOut
        )

        let oldRate = viewModelFactory.rateViewModel(from: oldRateParams)
        let newRate = viewModelFactory.rateViewModel(from: newRateParams)

        let title = R.string.localizable.swapsSetupErrorRateWasUpdatedTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        let message = R.string.localizable.swapsSetupErrorRateWasUpdatedMessage(
            oldRate,
            newRate,
            preferredLanguages: selectedLocale.rLanguages
        )
        let confirmTitle = R.string.localizable.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )
        let cancelTitle = R.string.localizable.commonCancel(
            preferredLanguages: selectedLocale.rLanguages
        )
        let confirmAction = AlertPresentableAction(title: confirmTitle, handler: confirmClosure)
        wireframe.present(
            viewModel: .init(
                title: title,
                message: message,
                actions: [confirmAction],
                closeAction: cancelTitle
            ),
            style: .alert,
            from: view
        )
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
        guard let address = chainAccountResponse.chainAccount.toAddress() else {
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
        view?.didReceiveStartLoading()
        let spendingAmount = quote?.amountIn.decimal(precision: initState.chainAssetIn.asset.precision)

        let validators = validators(spendingAmount: spendingAmount)

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            self?.submit()
        }
    }
}

extension SwapConfirmPresenter: SwapConfirmInteractorOutputProtocol {
    func didReceive(quote: AssetConversion.Quote, for _: AssetConversion.QuoteArgs) {
        checkRateChanged(
            oldValue: self.quote ?? initState.quote,
            newValue: quote
        ) { [weak self] in
            self?.quote = quote
            self?.provideAssetInViewModel()
            self?.provideAssetOutViewModel()
            self?.provideRateViewModel()
            self?.providePriceDifferenceViewModel()
            self?.estimateFee()
        }
    }

    func didReceive(fee: BigUInt?, transactionId _: TransactionFeeId) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        if priceId == initState.chainAssetIn.asset.priceId {
            chainAssetInPriceData = price
            provideAssetInViewModel()
            providePriceDifferenceViewModel()
        }
        if priceId == initState.chainAssetOut.asset.priceId {
            chainAssetOutPriceData = price
            provideAssetOutViewModel()
            providePriceDifferenceViewModel()
        }
        if priceId == initState.feeChainAsset.asset.priceId {
            feePriceData = price
            provideFeeViewModel()
        }
    }

    func didReceive(payAccountId: AccountId?) {
        self.payAccountId = payAccountId
        estimateFee()
    }

    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId, accountId _: AccountId) {
        balances[chainAsset] = balance
    }

    func didReceive(baseError: SwapSetupError) {
        switch baseError {
        case let .quote:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self, initState] in
                self?.interactor.calculateQuote(for: initState.quoteArgs)
            }
        case let .fetchFeeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                guard let self = self else {
                    return
                }
                [self.initState.chainAssetIn, self.initState.chainAssetOut, self.initState.feeChainAsset]
                    .compactMap { $0 }
                    .filter { $0.asset.priceId == priceId }
                    .forEach(self.interactor.remakePriceSubscription)
            }
        case let .assetBalance:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        }
    }

    func didReceive(error: SwapConfirmError) {
        view?.didReceiveStopLoading()
        switch error {
        case let .submit(error):
            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveConfirmation(hash _: String) {
        view?.didReceiveStopLoading()
        wireframe.complete(on: view, locale: selectedLocale)
    }
}

extension SwapConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            viewModelFactory.locale = selectedLocale
            updateViews()
        }
    }
}
