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

extension SwapIssueCheckParams {
    var hasEnteredAmount: Bool {
        (payAmount ?? 0) > 0 || (receiveAmount ?? 0) > 0
    }

    var isQuoting: Bool {
        payChainAsset != nil && receiveChainAsset != nil && hasEnteredAmount && quoteResult == nil
    }
}
