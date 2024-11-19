struct SwapConfirmInitState {
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let feeChainAsset: ChainAsset
    let slippage: BigRational
    let quote: AssetExchangeQuote
    let quoteArgs: AssetConversion.QuoteArgs
}
