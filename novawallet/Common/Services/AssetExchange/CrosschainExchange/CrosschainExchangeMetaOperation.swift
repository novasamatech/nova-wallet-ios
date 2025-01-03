import Foundation

final class CrosschainExchangeMetaOperation: AssetExchangeBaseMetaOperation {
    let requiresOriginAccountKeepAlive: Bool

    init(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        amountIn: Balance,
        amountOut: Balance,
        requiresOriginAccountKeepAlive: Bool
    ) {
        self.requiresOriginAccountKeepAlive = requiresOriginAccountKeepAlive

        super.init(
            assetIn: assetIn,
            assetOut: assetOut,
            amountIn: amountIn,
            amountOut: amountOut
        )
    }
}

extension CrosschainExchangeMetaOperation: AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel { .transfer }
}
