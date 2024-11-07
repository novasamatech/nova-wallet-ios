struct SwapConfirmInitState {
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let feeChainAsset: ChainAsset
    let slippage: BigRational
    let route: AssetExchangeRoute
    let quoteArgs: AssetConversion.QuoteArgs
}
