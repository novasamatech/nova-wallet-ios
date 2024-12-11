import Foundation

class SwapBasePresenter {
    let logger: LoggerProtocol
    let selectedWallet: MetaAccountModel
    let dataValidatingFactory: SwapDataValidatorFactoryProtocol

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

    private(set) var prices: [AssetModel.PriceId: PriceData] = [:]

    var payAssetPriceData: PriceData? {
        getPayChainAsset()?.asset.priceId.flatMap { prices[$0] }
    }

    var receiveAssetPriceData: PriceData? {
        getReceiveChainAsset()?.asset.priceId.flatMap { prices[$0] }
    }

    var feeAssetPriceData: PriceData? {
        getFeeChainAsset()?.asset.priceId.flatMap { prices[$0] }
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

    var fee: AssetExchangeFee?
    var quoteResult: Result<AssetExchangeQuote, Error>?

    var quote: AssetExchangeQuote? {
        switch quoteResult {
        case let .success(quote):
            return quote
        case .failure, .none:
            return nil
        }
    }

    var accountInfo: AccountInfo?

    init(
        selectedWallet: MetaAccountModel,
        dataValidatingFactory: SwapDataValidatorFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

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
            receiveChainAsset: getReceiveChainAsset(),
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

    func shouldHandleRoute(for _: AssetConversion.QuoteArgs?) -> Bool {
        fatalError("Must be implemented by parent class")
    }

    func estimateFee() {
        fatalError("Must be implemented by parent class")
    }

    func applySwapMax() {
        fatalError("Must be implemented by parent class")
    }

    func handleBaseError(_: SwapBaseError) {}

    func handleNewQuote(_: AssetExchangeQuote, for _: AssetConversion.QuoteArgs) {}

    func handleNewFee(
        _: AssetExchangeFee?,
        feeChainAssetId _: ChainAssetId?
    ) {}

    func handleNewPrice(_: PriceData?, priceId _: AssetModel.PriceId) {}

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
            guard shouldHandleRoute(for: args) else {
                return
            }

            quoteResult = .failure(error)
        case .fetchFeeFailed:
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                self?.estimateFee()
            }
        case let .assetBalanceExistence(_, chainAsset):
            wireframe.presentRequestStatus(on: view, locale: locale) {
                interactor.retryAssetBalanceExistenseFetch(for: chainAsset)
            }
        }
    }

    func getBaseValidations(
        for swapModel: SwapModel,
        interactor: SwapBaseInteractorInputProtocol,
        locale: Locale
    ) -> [DataValidating] {
        var baseValidations = [
            dataValidatingFactory.has(
                fee: swapModel.feeModel?.originExtrinsicFee(),
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
                fee: swapModel.feeChainAsset.isUtilityAsset ? swapModel.feeModel?.originExtrinsicFee() : nil,
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
            )
        ]

        // for a single operation validation is covered by canReceive
        if let operations = swapModel.quote?.metaOperations, operations.count > 1 {
            let intermediateEdValidation = dataValidatingFactory.passesIntermediateEDValidation(
                params: swapModel,
                remoteValidatingClosure: { closureParams in
                    interactor.requestValidatingIntermediateED(
                        for: closureParams.operations,
                        completion: closureParams.completionClosure
                    )
                },
                locale: locale
            )

            baseValidations.append(intermediateEdValidation)
        }

        let quoteValidation = dataValidatingFactory.passesRealtimeQuoteValidation(
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

        baseValidations.append(quoteValidation)

        return baseValidations
    }
}

extension SwapBasePresenter: SwapBaseInteractorOutputProtocol {
    func didReceive(quote: AssetExchangeQuote, for quoteArgs: AssetConversion.QuoteArgs) {
        guard shouldHandleRoute(for: quoteArgs) else {
            return
        }

        logger.debug("New quote: \(quote)")

        quoteResult = .success(quote)

        handleNewQuote(quote, for: quoteArgs)
    }

    func didReceive(fee: AssetExchangeFee, feeChainAssetId: ChainAssetId?) {
        guard self.fee != fee else {
            return
        }

        logger.debug("Did receive new fee: \(fee)")

        self.fee = fee

        handleNewFee(fee, feeChainAssetId: feeChainAssetId)
    }

    func didReceive(baseError: SwapBaseError) {
        logger.error("Did receive error: \(baseError)")

        handleBaseError(baseError)
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        guard prices[priceId] != price else {
            return
        }

        logger.debug("New price: \(String(describing: price))")

        prices[priceId] = price

        handleNewPrice(price, priceId: priceId)
    }

    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId) {
        guard balances[chainAsset] != balance else {
            return
        }

        logger.debug("New balance: \(String(describing: balance))")

        balances[chainAsset] = balance

        handleNewBalance(balance, for: chainAsset)
    }

    func didReceiveAssetBalance(existense: AssetBalanceExistence, chainAssetId: ChainAssetId) {
        guard assetBalanceExistences[chainAssetId] != existense else {
            return
        }

        logger.debug("New balance existence: \(existense)")

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
