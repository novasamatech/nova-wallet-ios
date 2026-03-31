import Foundation

extension AssetExchangeQuote {
    var involvesHydraSwap: Bool {
        hydraSwapOperation != nil
    }

    /// The last non-transfer operation on a Hydration chain (where the commission is taken)
    var hydraSwapOperation: AssetExchangeMetaOperationProtocol? {
        metaOperations.last { operation in
            !operation.label.isTransfer && operation.assetOut.chain.hasSwapHydra
        }
    }

    var willCollectCommission: Bool {
        involvesHydraSwap
    }

    var displayAmountOut: Balance {
        if willCollectCommission {
            return HydraConstants.amountOutAfterNovaFee(route.amountOut)
        } else {
            return route.amountOut
        }
    }
}
