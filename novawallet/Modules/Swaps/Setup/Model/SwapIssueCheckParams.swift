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

    /// Whether another tap-apply of a pool trade limit is still inside the correction budget (FR-17).
    /// Carried in so that the issue detection stays a pure function of its input.
    let canApplyPoolTradeLimit: Bool
}
