import Foundation
import RobinHood

struct HydraOmnipoolSwapParams {
    struct Params {
        let currentFeeCurrency: HydraDx.OmniPoolAssetId
        let newFeeCurrency: HydraDx.OmniPoolAssetId
        let referral: AccountId?

        var shouldSetFeeCurrency: Bool {
            newFeeCurrency != currentFeeCurrency
        }

        var shouldSetReferral: Bool {
            referral == nil
        }
    }

    enum Operation {
        case sell(HydraDx.SellCall)
        case buy(HydraDx.BuyCall)
    }

    let params: Params
    let changeFeeCurrency: HydraDx.SetCurrencyCall?
    let updateReferral: HydraDx.LinkReferralCodeCall?
    let swap: Operation

    var numberOfExtrinsics: Int {
        changeFeeCurrency != nil ? 2 : 1
    }

    var isFeeInNativeCurrency: Bool {
        params.newFeeCurrency == HydraDx.nativeAssetId
    }
}

protocol HydraOmnipoolExtrinsicOperationFactoryProtocol {
    func createOperationWrapper(
        for feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraOmnipoolSwapParams>
}

final class HydraOmnipoolExtrinsicOperationFactory {
    let chain: ChainModel
    let swapService: HydraOmnipoolSwapService
    let runtimeProvider: RuntimeCodingServiceProtocol

    init(
        chain: ChainModel,
        swapService: HydraOmnipoolSwapService,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) {
        self.chain = chain
        self.swapService = swapService
        self.runtimeProvider = runtimeProvider
    }

    private func createSwapParams(
        from params: HydraOmnipoolSwapParams.Params,
        remoteAssetIn: HydraDx.OmniPoolAssetId,
        remoteAssetOut: HydraDx.OmniPoolAssetId,
        callArgs: AssetConversion.CallArgs
    ) throws -> HydraOmnipoolSwapParams {
        let setCurrencyCall: HydraDx.SetCurrencyCall?

        if params.shouldSetFeeCurrency {
            setCurrencyCall = .init(currency: params.newFeeCurrency)
        } else {
            setCurrencyCall = nil
        }

        let referralCall: HydraDx.LinkReferralCodeCall?

        if params.shouldSetReferral {
            guard let code = HydraOmnipoolConstants.novaReferralCode.data(using: .utf8) else {
                throw CommonError.dataCorruption
            }

            referralCall = .init(code: code)
        } else {
            referralCall = nil
        }

        switch callArgs.direction {
        case .sell:
            let amountOutMin = callArgs.amountOut - callArgs.slippage.mul(value: callArgs.amountOut)

            let sellCall = HydraDx.SellCall(
                assetIn: remoteAssetIn,
                assetOut: remoteAssetOut,
                amount: callArgs.amountIn,
                minBuyAmount: amountOutMin
            )

            return HydraOmnipoolSwapParams(
                params: params,
                changeFeeCurrency: setCurrencyCall,
                updateReferral: referralCall,
                swap: .sell(sellCall)
            )
        case .buy:
            let amountInMax = callArgs.amountIn + callArgs.slippage.mul(value: callArgs.amountIn)

            let buyCall = HydraDx.BuyCall(
                assetOut: remoteAssetOut,
                assetIn: remoteAssetIn,
                amount: callArgs.amountOut,
                maxSellAmount: amountInMax
            )

            return HydraOmnipoolSwapParams(
                params: params,
                changeFeeCurrency: setCurrencyCall,
                updateReferral: referralCall,
                swap: .buy(buyCall)
            )
        }
    }

    private func createSwapOperationWrapper(
        assetIn: ChainAsset,
        assetOut: ChainAsset,
        feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraOmnipoolSwapParams> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let swapParamsOperation = swapService.createFetchOperation()

        let mergeOperation = ClosureOperation<HydraOmnipoolSwapParams> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let swapParams = try swapParamsOperation.extractNoCancellableResultData()

            let remoteFeeAsset = try HydraDxTokenConverter.convertToRemote(
                chainAsset: feeAsset,
                codingFactory: codingFactory
            ).remoteAssetId

            let remoteAssetIn = try HydraDxTokenConverter.convertToRemote(
                chainAsset: assetIn,
                codingFactory: codingFactory
            ).remoteAssetId

            let remoteAssetOut = try HydraDxTokenConverter.convertToRemote(
                chainAsset: assetOut,
                codingFactory: codingFactory
            ).remoteAssetId

            let params = HydraOmnipoolSwapParams.Params(
                currentFeeCurrency: swapParams.feeCurrency ?? HydraDx.nativeAssetId,
                newFeeCurrency: remoteFeeAsset,
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

extension HydraOmnipoolExtrinsicOperationFactory: HydraOmnipoolExtrinsicOperationFactoryProtocol {
    func createOperationWrapper(
        for feeAsset: ChainAsset,
        callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<HydraOmnipoolSwapParams> {
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
