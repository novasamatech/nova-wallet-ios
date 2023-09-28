import Foundation
import BigInt

enum AssetConversion {
    enum Direction {
        case sell
        case buy
    }

    struct Args {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
        let amount: BigUInt
        let direction: Direction
        let slippage: Decimal
    }

    struct Quote {
        let amountIn: BigUInt
        let assetIn: ChainAssetId
        let amountOut: BigUInt
        let assetOut: ChainAssetId
        let priceImpact: Decimal
        let fee: Fee
    }

    struct Fee {
        let serviceFee: Decimal
        let novaFee: Decimal?
    }
}
