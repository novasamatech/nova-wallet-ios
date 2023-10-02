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

        init(args: Args, amount: BigUInt) {
            switch args.direction {
            case .sell:
                amountIn = args.amount
                amountOut = amount
            case .buy:
                amountIn = amount
                amountOut = args.amount
            }

            assetIn = args.assetIn
            assetOut = args.assetOut
        }
    }
}
