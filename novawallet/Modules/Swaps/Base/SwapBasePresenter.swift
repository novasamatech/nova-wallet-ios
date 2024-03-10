import Foundation

class SwapBasePresenter {
    let logger: LoggerProtocol
    let selectedWallet: MetaAccountModel
    let dataValidatingFactory: SwapDataValidatorFactoryProtocol

    init(
        selectedWallet: MetaAccountModel,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    private(set) var balances: [ChainAssetId: AssetBalance] = [:]

    var payAssetBalance: AssetBalance? {
        getPayChainAsset().flatMap { balances[$0.chainAssetId] }
    }

    var feeAssetBalance: AssetBalance? {
        getFeeChainAsset().flatMap { balances[$0.chainAssetId] }
    }

    var receiveAssetBalance: AssetBalance? {
        getReceiveChainAsset().flatMap { balances[$0.chainAssetId] }
    }

    var utilityAssetBalance: AssetBalance? {
        guard let utilityAssetId = getFeeChainAsset()?.chain.utilityChainAssetId() else {
            return nil
        }

        return balances[utilityAssetId]
    }

    private(set) var prices: [ChainAssetId: PriceData] = [:]

    var payAssetPriceData: PriceData? {
        getPayChainAsset().flatMap { prices[$0.chainAssetId] }
    }

    var receiveAssetPriceData: PriceData? {
        getReceiveChainAsset().flatMap { prices[$0.chainAssetId] }
    }

    var feeAssetPriceData: PriceData? {
        getFeeChainAsset().flatMap { prices[$0.chainAssetId] }
    }

    var assetBalanceExistences: [ChainAssetId: AssetBalanceExistence] = [:]

    var payAssetBalanceExistense: AssetBalanceExistence? {
        getPayChainAsset().flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var receiveAssetBalanceExistense: AssetBalanceExistence? {
        getReceiveChainAsset().flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var feeAssetBalanceExistense: AssetBalanceExistence? {
        getFeeChainAsset().flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var utilityAssetBalanceExistense: AssetBalanceExistence? {
        getFeeChainAsset()?.chain.utilityChainAsset().flatMap {
            assetBalanceExistences[$0.chainAssetId]
        }
    }

    var fee: AssetConversion.FeeModel?
    var quoteResult: Result<AssetConversion.Quote, Error>?

    var quote: AssetConversion.Quote? {
        switch quoteResult {
        case let .success(quote):
            return quote
        case .failure, .none:
            return nil
        }
    }

    var accountInfo: AccountInfo?

    func getSwapModel() -> SwapModel? {
        guard
            let payChainAsset = getPayChainAsset(),
            let receiveChainAsset = getReceiveChainAsset(),
            let feeChainAsset = getFeeChainAsset(),
            let quoteArgs = getQuoteArgs() else {
            return nil
        }

        return .init(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: feeChainAsset,
            spendingAmount: getSpendingInputAmount(),
            payAssetBalance: payAssetBalance,
            feeAssetBalance: feeAssetBalance,
            receiveAssetBalance: receiveAssetBalance,
            utilityAssetBalance: utilityAssetBalance,
            payAssetExistense: payAssetBalanceExistense,
            receiveAssetExistense: receiveAssetBalanceExistense,
            feeAssetExistense: feeAssetBalanceExistense,
            utilityAssetExistense: utilityAssetBalanceExistense,
            feeModel: fee,
            quoteArgs: quoteArgs,
            quote: quote,
            slippage: getSlippage(),
            accountInfo: accountInfo
        )
    }

    func getMaxModel() -> SwapMaxModel? {
        .init(
            payChainAsset: getPayChainAsset(),
            feeChainAsset: getFeeChainAsset(),
            balance: payAssetBalance,
            feeModel: fee,
            payAssetExistense: payAssetBalanceExistense,
            receiveAssetExistense: receiveAssetBalanceExistense,
            accountInfo: accountInfo
        )
    }

    func getSpendingInputAmount() -> Decimal? {
        fatalError("Must be implemented by parent class")
    }

    func getQuoteArgs() -> AssetConversion.QuoteArgs? {
        fatalError("Must be implemented by parent class")
    }

    func getSlippage() -> BigRational {
        fatalError("Must be implemented by parent class")
    }

    func getPayChainAsset() -> ChainAsset? {
        fatalError("Must be implemented by parent class")
    }

    func getReceiveChainAsset() -> ChainAsset? {
        fatalError("Must be implemented by parent class")
    }

    func getFeeChainAsset() -> ChainAsset? {
        fatalError("Must be implemented by parent class")
    }

    func shouldHandleQuote(for _: AssetConversion.QuoteArgs?) -> Bool {
        fatalError("Must be implemented by parent class")
    }

    func shouldHandleFee(for _: TransactionFeeId, feeChainAssetId _: ChainAssetId?) -> Bool {
        fatalError("Must be implemented by parent class")
    }

    func estimateFee() {
        fatalError("Must be implemented by parent class")
    }

    func applySwapMax() {
        fatalError("Must be implemented by parent class")
    }

    func handleBaseError(_: SwapBaseError) {}

    func handleNewQuote(_: AssetConversion.Quote, for _: AssetConversion.QuoteArgs) {}

    func handleNewFee(
        _: AssetConversion.FeeModel?,
        transactionFeeId _: TransactionFeeId,
        feeChainAssetId _: ChainAssetId?
    ) {}

    func handleNewPrice(_: PriceData?, chainAssetId _: ChainAssetId) {}

    func handleNewBalance(_: AssetBalance?, for _: ChainAssetId) {}

    func handleNewBalanceExistense(_: AssetBalanceExistence, chainAssetId _: ChainAssetId) {}

    func handleNewAccountInfo(_: AccountInfo?, chainId _: ChainModel.Id) {}

    func handleBaseError(
        _ error: SwapBaseError,
        view: ControllerBackedProtocol?,
        interactor: SwapBaseInteractorInputProtocol,
        wireframe: SwapBaseWireframeProtocol,
        locale: Locale
    ) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case let .quote(error, args):
            guard shouldHandleQuote(for: args) else {
                return
            }

            quoteResult = .failure(error)
        case let .fetchFeeFailed(_, id, feeChainAssetId):
            guard shouldHandleFee(for: id, feeChainAssetId: feeChainAssetId) else {
                return
            }

            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                guard let self = self else {
                    return
                }
                [self.getPayChainAsset(), self.getReceiveChainAsset(), self.getFeeChainAsset()]
                    .compactMap { $0 }
                    .filter { $0.asset.priceId == priceId }
                    .forEach(interactor.remakePriceSubscription)
            }
        case let .assetBalance(_, chainAssetId, _):
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                guard let self = self else {
                    return
                }
                [self.getPayChainAsset(), self.getReceiveChainAsset(), self.getFeeChainAsset()]
                    .compactMap { $0 }
                    .filter { $0.chainAssetId == chainAssetId }
                    .forEach(interactor.retryAssetBalanceSubscription)
            }
        case let .assetBalanceExistense(_, chainAsset):
            wireframe.presentRequestStatus(on: view, locale: locale) {
                interactor.retryAssetBalanceExistenseFetch(for: chainAsset)
            }
        case .accountInfo:
            wireframe.presentRequestStatus(on: view, locale: locale) {
                interactor.retryAccountInfoSubscription()
            }
        }
    }

    func getBaseValidations(
        for swapModel: SwapModel,
        interactor: SwapBaseInteractorInputProtocol,
        locale: Locale
    ) -> [DataValidating] {
        [
            dataValidatingFactory.has(
                fee: swapModel.feeModel?.extrinsicFee,
                locale: locale
            ) { [weak self] in
                self?.estimateFee()
            },
            dataValidatingFactory.hasSufficientBalance(
                params: swapModel,
                swapMaxAction: { [weak self] in
                    self?.applySwapMax()
                },
                locale: locale
            ),
            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: swapModel.feeChainAsset.isUtilityAsset ? swapModel.feeModel?.extrinsicFee : nil,
                total: swapModel.utilityAssetBalance?.balanceCountingEd,
                minBalance: swapModel.feeChainAsset.isUtilityAsset ? swapModel.utilityAssetExistense?.minBalance : 0,
                asset: swapModel.utilityChainAsset?.assetDisplayInfo ?? swapModel.feeChainAsset.assetDisplayInfo,
                locale: locale
            ),
            dataValidatingFactory.canReceive(params: swapModel, locale: locale),
            dataValidatingFactory.noDustRemains(
                params: swapModel,
                swapMaxAction: { [weak self] in
                    self?.applySwapMax()
                },
                locale: locale
            ),
            dataValidatingFactory.passesRealtimeQuoteValidation(
                params: swapModel,
                remoteValidatingClosure: { args, completion in
                    interactor.requestValidatingQuote(for: args, completion: completion)
                },
                onQuoteUpdate: { [weak self] quote in
                    self?.quoteResult = .success(quote)
                    self?.handleNewQuote(quote, for: swapModel.quoteArgs)
                },
                locale: locale
            )
        ]
    }
}

extension SwapBasePresenter: SwapBaseInteractorOutputProtocol {
    func didReceive(quote: AssetConversion.Quote, for quoteArgs: AssetConversion.QuoteArgs) {
        guard shouldHandleQuote(for: quoteArgs), self.quote != quote else {
            return
        }

        quoteResult = .success(quote)

        handleNewQuote(quote, for: quoteArgs)
    }

    func didReceive(
        fee: AssetConversion.FeeModel?,
        transactionFeeId: TransactionFeeId,
        feeChainAssetId: ChainAssetId?
    ) {
        guard shouldHandleFee(for: transactionFeeId, feeChainAssetId: feeChainAssetId), self.fee != fee else {
            return
        }

        self.fee = fee

        handleNewFee(fee, transactionFeeId: transactionFeeId, feeChainAssetId: feeChainAssetId)
    }

    func didReceive(baseError: SwapBaseError) {
        handleBaseError(baseError)
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        let optChainAssetId = [getPayChainAsset(), getReceiveChainAsset(), getFeeChainAsset()]
            .compactMap { $0 }
            .filter { $0.asset.priceId == priceId }
            .first?.chainAssetId

        guard let chainAssetId = optChainAssetId, prices[chainAssetId] != price else {
            return
        }

        prices[chainAssetId] = price

        handleNewPrice(price, chainAssetId: chainAssetId)
    }

    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId) {
        guard balances[chainAsset] != balance else {
            return
        }

        balances[chainAsset] = balance

        handleNewBalance(balance, for: chainAsset)
    }

    func didReceiveAssetBalance(existense: AssetBalanceExistence, chainAssetId: ChainAssetId) {
        guard assetBalanceExistences[chainAssetId] != existense else {
            return
        }

        assetBalanceExistences[chainAssetId] = existense

        handleNewBalanceExistense(existense, chainAssetId: chainAssetId)
    }

    func didReceive(accountInfo: AccountInfo?, chainId: ChainModel.Id) {
        guard self.accountInfo != accountInfo else {
            return
        }

        logger.debug("New account info: \(String(describing: accountInfo))")

        self.accountInfo = accountInfo

        handleNewAccountInfo(accountInfo, chainId: chainId)
    }
}
