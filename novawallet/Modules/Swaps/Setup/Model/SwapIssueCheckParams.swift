import Foundation

struct SwapIssueCheckParams {
    let payChainAsset: ChainAsset?
    let receiveChainAsset: ChainAsset?
    let payAmount: Decimal?
    let receiveAmount: Decimal?
    let payAssetBalance: AssetBalance?
    let receiveAssetBalance: AssetBalance?
    let payAssetExistense: AssetBalanceExistence?
    let receiveAssetExistense: AssetBalanceExistence?
    let quoteResult: Result<AssetExchangeQuote, Error>?
    let fee: AssetExchangeFee?
}
