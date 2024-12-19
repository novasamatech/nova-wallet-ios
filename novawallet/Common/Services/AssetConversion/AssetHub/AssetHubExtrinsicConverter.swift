import Foundation
import SubstrateSdk

enum AssetHubExtrinsicConverterError: Error {
    case remoteAssetNotFound(ChainAssetId)
}

enum AssetHubExtrinsicConverter {
    static func addingOperation(
        to builder: ExtrinsicBuilderProtocol,
        chain: ChainModel,
        args: AssetConversion.CallArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard
            let remoteAssetIn = AssetHubTokensConverter.convertToMultilocation(
                chainAssetId: args.assetIn,
                chain: chain,
                codingFactory: codingFactory
            ) else {
            throw AssetHubExtrinsicConverterError.remoteAssetNotFound(args.assetIn)
        }

        guard
            let remoteAssetOut = AssetHubTokensConverter.convertToMultilocation(
                chainAssetId: args.assetOut,
                chain: chain,
                codingFactory: codingFactory
            ) else {
            throw AssetHubExtrinsicConverterError.remoteAssetNotFound(args.assetOut)
        }

        switch args.direction {
        case .sell:
            let amountOutMin = args.amountOut - args.slippage.mul(value: args.amountOut)

            let call = AssetConversionPallet.SwapExactTokensForTokensCall(
                path: [remoteAssetIn, remoteAssetOut],
                amountIn: args.amountIn,
                amountOutMin: amountOutMin,
                sendTo: args.receiver,
                keepAlive: false
            )

            return try builder.adding(call: call.runtimeCall(for: AssetConversionPallet.name))
        case .buy:
            let amountInMax = args.amountIn + args.slippage.mul(value: args.amountIn)

            let call = AssetConversionPallet.SwapTokensForExactTokensCall(
                path: [remoteAssetIn, remoteAssetOut],
                amountOut: args.amountOut,
                amountInMax: amountInMax,
                sendTo: args.receiver,
                keepAlive: false
            )

            return try builder.adding(call: call.runtimeCall(for: AssetConversionPallet.name))
        }
    }
}
