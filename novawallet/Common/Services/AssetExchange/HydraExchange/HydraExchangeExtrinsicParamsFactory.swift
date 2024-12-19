import Foundation
import Operation_iOS

struct HydraExchangeSwapParams {
    struct Params {
        let referral: AccountId?

        var shouldSetReferral: Bool {
            referral == nil
        }
    }

    enum Operation {
        case omniSell(HydraOmnipool.SellCall)
        case omniBuy(HydraOmnipool.BuyCall)
        case routedSell(HydraRouter.SellCall)
        case routedBuy(HydraRouter.BuyCall)
    }

    let params: Params
    let updateReferral: HydraDx.LinkReferralCodeCall?
    let swap: Operation
}

protocol HydraExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        for route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams>
}

final class HydraExchangeExtrinsicParamsFactory {
    let chain: ChainModel
    let swapService: HydraSwapParamsService
    let runtimeProvider: RuntimeCodingServiceProtocol

    init(
        chain: ChainModel,
        swapService: HydraSwapParamsService,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) {
        self.chain = chain
        self.swapService = swapService
        self.runtimeProvider = runtimeProvider
    }

    private func createOperation(
        for remoteAssetIn: HydraDx.AssetId,
        remoteAssetOut: HydraDx.AssetId,
        callArgs: AssetConversion.CallArgs,
        route: HydraDx.RemoteSwapRoute
    ) -> HydraExchangeSwapParams.Operation {
        switch callArgs.direction {
        case .sell:
            let amountOutMin = callArgs.amountOut - callArgs.slippage.mul(value: callArgs.amountOut)

            if HydraExtrinsicConverter.isOmnipoolSwap(route: route) {
                return .omniSell(
                    HydraOmnipool.SellCall(
                        assetIn: remoteAssetIn,
                        assetOut: remoteAssetOut,
                        amount: callArgs.amountIn,
                        minBuyAmount: amountOutMin
                    )
                )
            } else {
                return .routedSell(
                    HydraRouter.SellCall(
                        assetIn: remoteAssetIn,
                        assetOut: remoteAssetOut,
                        amountIn: callArgs.amountIn,
                        minAmountOut: amountOutMin,
                        route: HydraExtrinsicConverter.convertRouteToTrade(route)
                    )
                )
            }
        case .buy:
            let amountInMax = callArgs.amountIn + callArgs.slippage.mul(value: callArgs.amountIn)

            if HydraExtrinsicConverter.isOmnipoolSwap(route: route) {
                return .omniBuy(
                    HydraOmnipool.BuyCall(
                        assetOut: remoteAssetOut,
                        assetIn: remoteAssetIn,
                        amount: callArgs.amountOut,
                        maxSellAmount: amountInMax
                    )
                )
            } else {
                return .routedBuy(
                    HydraRouter.BuyCall(
                        assetIn: remoteAssetIn,
                        assetOut: remoteAssetOut,
                        amountOut: callArgs.amountOut,
                        maxAmountIn: amountInMax,
                        route: HydraExtrinsicConverter.convertRouteToTrade(route)
                    )
                )
            }
        }
    }

    private func createSwapParams(
        from params: HydraExchangeSwapParams.Params,
        remoteAssetIn: HydraDx.AssetId,
        remoteAssetOut: HydraDx.AssetId,
        route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs
    ) throws -> HydraExchangeSwapParams {
        let referralCall: HydraDx.LinkReferralCodeCall?

        if params.shouldSetReferral {
            let code = try HydraConstants.novaReferralCode.data(using: .utf8).mapOrThrow(CommonError.dataCorruption)

            referralCall = .init(code: code)
        } else {
            referralCall = nil
        }

        let operation = createOperation(
            for: remoteAssetIn,
            remoteAssetOut: remoteAssetOut,
            callArgs: callArgs,
            route: route
        )

        return HydraExchangeSwapParams(
            params: params,
            updateReferral: referralCall,
            swap: operation
        )
    }

    private func createSwapOperationWrapper(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let swapParamsOperation = swapService.createFetchOperation()

        let mergeOperation = ClosureOperation<HydraExchangeSwapParams> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let swapParams = try swapParamsOperation.extractNoCancellableResultData()

            let remoteAssetIn = try HydraDxTokenConverter.convertToRemote(
                chainAsset: assetIn,
                codingFactory: codingFactory
            ).remoteAssetId

            let remoteAssetOut = try HydraDxTokenConverter.convertToRemote(
                chainAsset: assetOut,
                codingFactory: codingFactory
            ).remoteAssetId

            let params = HydraExchangeSwapParams.Params(referral: swapParams.referralLink)

            return try self.createSwapParams(
                from: params,
                remoteAssetIn: remoteAssetIn,
                remoteAssetOut: remoteAssetOut,
                route: route,
                callArgs: callArgs
            )
        }

        mergeOperation.addDependency(codingFactoryOperation)
        mergeOperation.addDependency(swapParamsOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [codingFactoryOperation, swapParamsOperation]
        )
    }
}

extension HydraExchangeExtrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        for route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        guard let assetIn = chain.asset(for: callArgs.assetIn.assetId) else {
            return .createWithError(
                ChainModelFetchError.noAsset(assetId: callArgs.assetIn.assetId)
            )
        }

        guard let assetOut = chain.asset(for: callArgs.assetOut.assetId) else {
            return .createWithError(
                ChainModelFetchError.noAsset(assetId: callArgs.assetOut.assetId)
            )
        }

        return createSwapOperationWrapper(
            assetIn: .init(chain: chain, asset: assetIn),
            assetOut: .init(chain: chain, asset: assetOut),
            route: route,
            callArgs: callArgs
        )
    }
}
