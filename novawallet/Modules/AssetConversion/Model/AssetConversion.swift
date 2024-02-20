import Foundation
import BigInt

enum AssetConversion {
    enum Direction {
        case sell
        case buy
    }

    struct QuoteArgs: Equatable {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
        let amount: BigUInt
        let direction: Direction
    }

    struct Quote: Equatable {
        let amountIn: BigUInt
        let assetIn: ChainAssetId
        let amountOut: BigUInt
        let assetOut: ChainAssetId
        let context: String?

        init(args: QuoteArgs, amount: BigUInt, context: String?) {
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
            self.context = context
        }

        func matches(other quote: Quote, slippage: BigRational, direction: Direction) -> Bool {
            switch direction {
            case .sell:
                let amountOutMin = amountOut - slippage.mul(value: amountOut)

                return amountOutMin <= quote.amountOut
            case .buy:
                let amountInMax = amountIn + slippage.mul(value: amountIn)

                return amountInMax >= quote.amountIn
            }
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
        let context: String?
    }
}

extension AssetConversion.CallArgs {
    var identifier: String { "\(hashValue)" }
}
