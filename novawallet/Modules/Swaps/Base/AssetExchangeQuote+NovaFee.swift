import Foundation

extension AssetExchangeQuote {
    /// The last non-transfer operation on a Hydration chain (where the commission is taken)
    var hydraSwapOperation: AssetExchangeMetaOperationProtocol? {
        metaOperations.last { operation in
            !operation.label.isTransfer && operation.assetOut.chain.hasSwapHydra
        }
    }

    var willCollectCommission: Bool {
        hydraSwapOperation != nil
    }

    /// Amount-out with the Nova fee deducted using the same base the commission is actually
    /// computed from in `NovaSwapCommissionClosureFactory` (post-slippage `minAmountOut` on the
    /// Hydra swap leg). Keeps display and execution fee bases aligned.
    func displayAmountOut(slippage: BigRational) -> Balance {
        guard let hydraSwapOp = hydraSwapOperation else {
            return route.amountOut
        }

        let hydraMinAmountOut = hydraSwapOp.amountOut - slippage.mul(value: hydraSwapOp.amountOut)
        let feeAmount = HydraConstants.novaSwapFeeAmount(from: hydraMinAmountOut)

        return route.amountOut.subtractOrZero(feeAmount)
    }
}
