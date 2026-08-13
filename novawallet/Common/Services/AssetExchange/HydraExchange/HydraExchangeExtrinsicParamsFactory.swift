import Foundation
import Operation_iOS

struct HydraExchangeSwapParams {
    struct Params {
        let referral: AccountId?

        var shouldSetReferral: Bool {
            referral == nil
        }
    }

    struct Commission {
        let amount: Balance
        let beneficiary: AccountId
        let assetStorageInfo: AssetStorageInfo
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
    let commission: Commission?
}

protocol HydraExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        for route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams>
}

final class HydraExchangeExtrinsicParamsFactory {
    let chain: ChainModel
    let swapService: HydraSwapParamsService
    let runtimeProvider: RuntimeCodingServiceProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol

    init(
        chain: ChainModel,
        swapService: HydraSwapParamsService,
        runtimeProvider: RuntimeCodingServiceProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    ) {
        self.chain = chain
        self.swapService = swapService
        self.runtimeProvider = runtimeProvider
        self.assetStorageInfoFactory = assetStorageInfoFactory
    }

    static func commissionAmount(
        for commission: AssetExchangeCommission,
        callArgs: AssetConversion.CallArgs
    ) -> Balance {
        let rateBasedAmount = commission.rateOfGross.mul(value: callArgs.amountOut)

        return min(commission.estimatedAmount, rateBasedAmount)
    }

    static func minimumChargeableAmount(for storageInfo: AssetStorageInfo) -> Balance? {
        switch storageInfo {
        case let .orml(info), let .ormlHydrationEvm(info):
            // The ED comes from the remote chains config, which can carry a stale or
            // missing value for an asset whose real ED is not 0 - HOLLAR shipped as "0"
            // against an on-chain 0.02. Treat 0 as unknown rather than as no floor,
            // otherwise a sub-ED commission gets attached and fails the whole atomic batch.
            return info.existentialDeposit > 0 ? info.existentialDeposit : nil
        case .native:
            // Readiness already proved the beneficiary holds at least the native ED,
            // so any incoming amount leaves it above ED.
            return 0
        default:
            return nil
        }
    }

    static func commissionParams(
        for commission: AssetExchangeCommission?,
        storageInfo: AssetStorageInfo?,
        callArgs: AssetConversion.CallArgs
    ) -> HydraExchangeSwapParams.Commission? {
        guard let commission, let storageInfo else {
            return nil
        }

        let amount = commissionAmount(for: commission, callArgs: callArgs)

        guard amount > 0 else {
            return nil
        }

        guard
            let minimumAmount = minimumChargeableAmount(for: storageInfo),
            amount >= minimumAmount else {
            return nil
        }

        return .init(
            amount: amount,
            beneficiary: commission.beneficiary,
            assetStorageInfo: storageInfo
        )
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

    private func createCommissionStorageInfoWrapper(
        for commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<AssetStorageInfo?> {
        guard let commission else {
            return .createWithResult(nil)
        }

        guard let asset = chain.asset(for: commission.asset.assetId) else {
            return .createWithError(
                ChainModelFetchError.noAsset(assetId: commission.asset.assetId)
            )
        }

        let wrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeProvider
        )

        let mappingOperation = ClosureOperation<AssetStorageInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    private func createSwapParams(
        from params: HydraExchangeSwapParams.Params,
        remoteAssetIn: HydraDx.AssetId,
        remoteAssetOut: HydraDx.AssetId,
        route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?,
        commissionStorageInfo: AssetStorageInfo?
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
            swap: operation,
            commission: Self.commissionParams(
                for: commission,
                storageInfo: commissionStorageInfo,
                callArgs: callArgs
            )
        )
    }

    private func createSwapOperationWrapper(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let swapParamsOperation = swapService.createFetchOperation()

        let storageInfoWrapper = createCommissionStorageInfoWrapper(for: commission)

        let mergeOperation = ClosureOperation<HydraExchangeSwapParams> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let swapParams = try swapParamsOperation.extractNoCancellableResultData()
            let commissionStorageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

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
                callArgs: callArgs,
                commission: commission,
                commissionStorageInfo: commissionStorageInfo
            )
        }

        mergeOperation.addDependency(codingFactoryOperation)
        mergeOperation.addDependency(swapParamsOperation)
        mergeOperation.addDependency(storageInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [codingFactoryOperation, swapParamsOperation] + storageInfoWrapper.allOperations
        )
    }
}

extension HydraExchangeExtrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        for route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?
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
            callArgs: callArgs,
            commission: commission
        )
    }
}
