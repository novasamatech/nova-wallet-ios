import BigInt

protocol SwapBaseInteractorInputProtocol: AnyObject {
    func setup()
    func calculateQuote(for args: AssetConversion.QuoteArgs)
    func calculateFee(for route: AssetExchangeRoute, slippage: BigRational, feeAsset: ChainAsset)
    func retryAssetBalanceExistenseFetch(for chainAsset: ChainAsset)

    func requestValidatingQuote(
        for args: AssetConversion.QuoteArgs,
        completion: @escaping (Result<AssetExchangeQuote, Error>) -> Void
    )

    func requestValidatingIntermediateED(
        for operations: [AssetExchangeMetaOperationProtocol],
        completion: @escaping SwapInterEDCheckClosure
    )
}

protocol SwapBaseInteractorOutputProtocol: AnyObject {
    func didReceive(quote: AssetExchangeQuote, for quoteArgs: AssetConversion.QuoteArgs)
    func didReceive(fee: AssetExchangeFee, feeChainAssetId: ChainAssetId?)
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
    case fetchFeeFailed(Error, ChainAssetId?)
    case assetBalanceExistence(Error, ChainAsset)
}
