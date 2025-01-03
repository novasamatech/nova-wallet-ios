import Foundation

enum AssetExchangeMetaOperationLabel: Equatable {
    case swap
    case transfer

    var isTransfer: Bool {
        switch self {
        case .transfer:
            true
        case .swap:
            false
        }
    }
}

protocol AssetExchangeMetaOperationProtocol {
    var assetIn: ChainAsset { get }
    var assetOut: ChainAsset { get }
    var amountIn: Balance { get }
    var amountOut: Balance { get }
    var label: AssetExchangeMetaOperationLabel { get }
    var requiresOriginAccountKeepAlive: Bool { get }
}

class AssetExchangeBaseMetaOperation {
    let assetIn: ChainAsset
    let assetOut: ChainAsset
    let amountIn: Balance
    let amountOut: Balance

    init(assetIn: ChainAsset, assetOut: ChainAsset, amountIn: Balance, amountOut: Balance) {
        self.assetIn = assetIn
        self.assetOut = assetOut
        self.amountIn = amountIn
        self.amountOut = amountOut
    }
}
