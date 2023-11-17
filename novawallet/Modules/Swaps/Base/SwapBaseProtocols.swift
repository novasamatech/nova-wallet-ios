import BigInt

protocol SwapBaseInteractorInputProtocol: AnyObject {
    func setup()
    func calculateQuote(for args: AssetConversion.QuoteArgs)
    func calculateFee(args: AssetConversion.CallArgs)
    func remakePriceSubscription(for chainAsset: ChainAsset)
    func retryAssetBalanceSubscription(for chainAsset: ChainAsset)
    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset)
    func retryAccountInfoSubscription()
    func requestValidatingQuote(
        for args: AssetConversion.QuoteArgs,
        completion: @escaping (Result<AssetConversion.Quote, Error>) -> Void
    )
}

protocol SwapBaseInteractorOutputProtocol: AnyObject {
    func didReceive(quote: AssetConversion.Quote, for quoteArgs: AssetConversion.QuoteArgs)
    func didReceive(fee: AssetConversion.FeeModel?, transactionFeeId: TransactionFeeId, feeChainAssetId: ChainAssetId?)
    func didReceive(baseError: SwapBaseError)
    func didReceive(price: PriceData?, priceId: AssetModel.PriceId)
    func didReceive(balance: AssetBalance?, for chainAsset: ChainAssetId)
    func didReceiveAssetBalance(existense: AssetBalanceExistence, chainAssetId: ChainAssetId)
    func didReceive(accountInfo: AccountInfo?, chainId: ChainModel.Id)
}

protocol SwapBaseWireframeProtocol: AnyObject, SwapErrorPresentable, AlertPresentable,
    CommonRetryable, ErrorPresentable {}

enum SwapBaseError: Error {
    case quote(Error, AssetConversion.QuoteArgs)
    case fetchFeeFailed(Error, TransactionFeeId, FeeChainAssetId?)
    case price(Error, AssetModel.PriceId)
    case assetBalance(Error, ChainAssetId, AccountId)
    case assetBalanceExistense(Error, ChainAsset)
    case accountInfo(Error)
}
