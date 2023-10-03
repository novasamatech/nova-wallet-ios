import Foundation
import SubstrateSdk

final class AssetHubExtrinsicService {
    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private func fetchExtrinsicBuilderClosure(
        for args: AssetConversion.CallArgs,
        codingFactory: RuntimeCoderFactoryProtocol,
        chain: ChainModel
    ) -> ExtrinsicBuilderClosure {
        { builder in

            guard
                let remoteAssetIn = AssetHubTokensConverter.convertToMultilocation(
                    chainAssetId: args.assetIn,
                    chain: chain,
                    codingFactory: codingFactory
                ) else {
                throw AssetConversionExtrinsicServiceError.remoteAssetNotFound(args.assetIn)
            }

            guard
                let remoteAssetOut = AssetHubTokensConverter.convertToMultilocation(
                    chainAssetId: args.assetOut,
                    chain: chain,
                    codingFactory: codingFactory
                ) else {
                throw AssetConversionExtrinsicServiceError.remoteAssetNotFound(args.assetOut)
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
}

extension AssetHubExtrinsicService: AssetConversionExtrinsicServiceProtocol {
    func fetchExtrinsicBuilderClosure(
        for args: AssetConversion.CallArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicBuilderClosure {
        fetchExtrinsicBuilderClosure(for: args, codingFactory: codingFactory, chain: chain)
    }
}
