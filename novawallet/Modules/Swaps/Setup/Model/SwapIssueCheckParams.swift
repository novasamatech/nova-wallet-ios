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
    let isFeePending: Bool
    let refreshOrigin: SwapRefreshOrigin
    let isPayAmountHidden: Bool
    let wasShowingInsufficientBalance: Bool
}

extension SwapIssueCheckParams {
    var hasEnteredAmount: Bool {
        Self.isQuotable(amount: payAmount, chainAsset: payChainAsset) ||
            Self.isQuotable(amount: receiveAmount, chainAsset: receiveChainAsset)
    }

    var isQuoting: Bool {
        payChainAsset != nil && receiveChainAsset != nil && hasEnteredAmount && (quoteResult == nil || isFeePending)
    }

    var hasNoRoute: Bool {
        guard case let .failure(error) = quoteResult else {
            return false
        }

        return SwapQuoteFailure(error: error) == .noRoute
    }
}

private extension SwapIssueCheckParams {
    static func isQuotable(amount: Decimal?, chainAsset: ChainAsset?) -> Bool {
        guard let amount, amount > 0 else {
            return false
        }

        guard let chainAsset else {
            return true
        }

        let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0

        return amountInPlank > 0
    }
}
