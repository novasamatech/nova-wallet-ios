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
    struct CommissionContext {
        let storageInfo: AssetStorageInfo
        let existentialDeposit: Balance
    }

    let chain: ChainModel
    let swapService: HydraSwapParamsService
    let runtimeProvider: RuntimeCodingServiceProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        swapService: HydraSwapParamsService,
        runtimeProvider: RuntimeCodingServiceProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.swapService = swapService
        self.runtimeProvider = runtimeProvider
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.operationQueue = operationQueue
    }

    static func commissionAmount(
        for commission: AssetExchangeCommission,
        callArgs: AssetConversion.CallArgs
    ) -> Balance {
        let rateBasedAmount = commission.rateOfGross.mul(value: callArgs.amountOut)

        return min(commission.estimatedAmount, rateBasedAmount)
    }

    static func commissionParams(
        for commission: AssetExchangeCommission?,
        context: CommissionContext?,
        callArgs: AssetConversion.CallArgs
    ) -> HydraExchangeSwapParams.Commission? {
        guard let commission, let context else {
            return nil
        }

        let amount = commissionAmount(for: commission, callArgs: callArgs)

        guard amount > 0, amount >= context.existentialDeposit else {
            return nil
        }

        return .init(
            amount: amount,
            beneficiary: commission.beneficiary,
            assetStorageInfo: context.storageInfo
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

    private func createCommissionContextWrapper(
        for commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<CommissionContext?> {
        guard let commission else {
            return .createWithResult(nil)
        }

        guard let asset = chain.asset(for: commission.asset.assetId) else {
            return .createWithError(
                ChainModelFetchError.noAsset(assetId: commission.asset.assetId)
            )
        }

        let storageInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeProvider
        )

        let existenceWrapper: CompoundOperationWrapper<AssetBalanceExistence>
        existenceWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

            return self.assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                for: storageInfo,
                chainId: self.chain.chainId,
                asset: asset
            )
        }

        existenceWrapper.addDependency(wrapper: storageInfoWrapper)

        let mappingOperation = ClosureOperation<CommissionContext?> {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()
            let existence = try existenceWrapper.targetOperation.extractNoCancellableResultData()

            return CommissionContext(
                storageInfo: storageInfo,
                existentialDeposit: existence.minBalance
            )
        }

        mappingOperation.addDependency(existenceWrapper.targetOperation)

        return existenceWrapper
            .insertingHead(operations: storageInfoWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    private func createSwapParams(
        from params: HydraExchangeSwapParams.Params,
        remoteAssetIn: HydraDx.AssetId,
        remoteAssetOut: HydraDx.AssetId,
        route: HydraDx.RemoteSwapRoute,
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?,
        commissionContext: CommissionContext?
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
                context: commissionContext,
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

        let commissionContextWrapper = createCommissionContextWrapper(for: commission)

        let mergeOperation = ClosureOperation<HydraExchangeSwapParams> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let swapParams = try swapParamsOperation.extractNoCancellableResultData()
            let commissionContext = try commissionContextWrapper.targetOperation.extractNoCancellableResultData()

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
                commissionContext: commissionContext
            )
        }

        mergeOperation.addDependency(codingFactoryOperation)
        mergeOperation.addDependency(swapParamsOperation)
        mergeOperation.addDependency(commissionContextWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [codingFactoryOperation, swapParamsOperation] + commissionContextWrapper.allOperations
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
