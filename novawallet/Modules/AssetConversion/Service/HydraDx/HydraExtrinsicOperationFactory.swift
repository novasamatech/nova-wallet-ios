import Foundation
import Operation_iOS

struct HydraSwapParams {
    struct Params {
        let newFeeCurrency: ChainAssetId
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

protocol HydraExtrinsicOperationFactoryProtocol {
    func createOperationWrapper(
        for feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraSwapParams>
}

final class HydraExtrinsicOperationFactory {
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
    ) -> HydraSwapParams.Operation {
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
        from params: HydraSwapParams.Params,
        remoteAssetIn: HydraDx.AssetId,
        remoteAssetOut: HydraDx.AssetId,
        callArgs: AssetConversion.CallArgs
    ) throws -> HydraSwapParams {
        let referralCall: HydraDx.LinkReferralCodeCall?

        if params.shouldSetReferral {
            guard let code = HydraConstants.novaReferralCode.data(using: .utf8) else {
                throw CommonError.dataCorruption
            }

            referralCall = .init(code: code)
        } else {
            referralCall = nil
        }

        guard let context = callArgs.context else {
            throw CommonError.dataCorruption
        }

        let route: HydraDx.RemoteSwapRoute = try JsonStringify.decodeFromString(context)

        let operation = createOperation(
            for: remoteAssetIn,
            remoteAssetOut: remoteAssetOut,
            callArgs: callArgs,
            route: route
        )

        return HydraSwapParams(
            params: params,
            updateReferral: referralCall,
            swap: operation
        )
    }

    private func createSwapOperationWrapper(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraSwapParams> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let swapParamsOperation = swapService.createFetchOperation()

        let mergeOperation = ClosureOperation<HydraSwapParams> {
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

            let params = HydraSwapParams.Params(
                newFeeCurrency: feeAsset.chainAssetId,
                referral: swapParams.referralLink
            )

            return try self.createSwapParams(
                from: params,
                remoteAssetIn: remoteAssetIn,
                remoteAssetOut: remoteAssetOut,
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

extension HydraExtrinsicOperationFactory: HydraExtrinsicOperationFactoryProtocol {
    func createOperationWrapper(
        for feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraSwapParams> {
        guard let assetIn = chain.asset(for: callArgs.assetIn.assetId) else {
            return CompoundOperationWrapper.createWithError(
                ChainModelFetchError.noAsset(assetId: callArgs.assetIn.assetId)
            )
        }

        guard let assetOut = chain.asset(for: callArgs.assetOut.assetId) else {
            return CompoundOperationWrapper.createWithError(
                ChainModelFetchError.noAsset(assetId: callArgs.assetOut.assetId)
            )
        }

        return createSwapOperationWrapper(
            assetIn: .init(chain: chain, asset: assetIn),
            assetOut: .init(chain: chain, asset: assetOut),
            feeAsset: feeAsset,
            callArgs: callArgs
        )
    }
}
