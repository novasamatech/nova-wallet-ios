import Foundation
import BigInt

enum AssetConversion {
    enum Direction: Equatable {
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
    }

    struct CallArgs: Hashable {
        let assetIn: ChainAssetId
        let amountIn: BigUInt
        let assetOut: ChainAssetId
        let amountOut: BigUInt
        let receiver: AccountId
        let direction: Direction
        let slippage: BigRational
        let context: String? // TODO: Get rid of the field
    }
}

extension AssetConversion.CallArgs {
    var identifier: String { "\(hashValue)" }
}
