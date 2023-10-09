import Foundation
import BigInt

enum AssetConversion {
    enum Direction {
        case sell
        case buy
    }

    struct QuoteArgs {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
        let amount: BigUInt
        let direction: Direction
    }

    struct Quote {
        let amountIn: BigUInt
        let assetIn: ChainAssetId
        let amountOut: BigUInt
        let assetOut: ChainAssetId

        init(args: QuoteArgs, amount: BigUInt) {
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

    struct CallArgs: Hashable {
        let assetIn: ChainAssetId
        let amountIn: BigUInt
        let assetOut: ChainAssetId
        let amountOut: BigUInt
        let receiver: AccountId
        let direction: Direction
        let slippage: BigRational
    }
}
