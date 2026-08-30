import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraOmnipoolQuoteFactory {
    private struct PalletConstants {
        let defaultFee: HydraDx.FeeEntry
        let limits: HydraExchangeTradeLimits.PoolLimits
    }

    let flowState: HydraOmnipoolFlowState

    init(flowState: HydraOmnipoolFlowState) {
        self.flowState = flowState
    }

    private func createQuoteStateWrapper(
        for remoteSwapPair: HydraDx.RemoteSwapPair
    ) -> CompoundOperationWrapper<HydraOmnipool.QuoteRemoteState> {
        let quoteService = flowState.setupQuoteService(for: remoteSwapPair)

        let operation = quoteService.createFetchOperation()

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createPalletConstantsWrapper() -> CompoundOperationWrapper<PalletConstants> {
        let coderFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let assetFeeOperation = StorageConstantOperation<HydraDx.FeeParameters>.operation(
            path: HydraDx.assetFeeParametersPath,
            dependingOn: coderFactoryOperation
        )

        assetFeeOperation.addDependency(coderFactoryOperation)

        let protocolFeeOperation = StorageConstantOperation<HydraDx.FeeParameters>.operation(
            path: HydraDx.protocolFeeParametersPath,
            dependingOn: coderFactoryOperation
        )

        protocolFeeOperation.addDependency(coderFactoryOperation)

        let limitsWrapper = HydraExchangeTradeLimits.createPoolLimitsWrapper(
            for: .omnipool,
            dependingOn: coderFactoryOperation
        )

        let mergeOperation = ClosureOperation<PalletConstants> {
            let assetFee = try assetFeeOperation.extractNoCancellableResultData().minFee
            let protocolFee = try protocolFeeOperation.extractNoCancellableResultData().minFee

            let limits = try limitsWrapper.targetOperation.extractNoCancellableResultData()

            return PalletConstants(
                defaultFee: HydraDx.FeeEntry(assetFee: assetFee, protocolFee: protocolFee),
                limits: limits
            )
        }

        mergeOperation.addDependency(assetFeeOperation)
        mergeOperation.addDependency(protocolFeeOperation)
        mergeOperation.addDependency(limitsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [
                coderFactoryOperation,
                assetFeeOperation,
                protocolFeeOperation
            ] + limitsWrapper.allOperations
        )
    }

    private func deriveApiParams(
        from remoteState: HydraOmnipool.QuoteRemoteState,
        defaultFee: HydraDx.FeeEntry
    ) throws -> HydraOmnipoolApi.Params {
        guard let assetInState = remoteState.assetInState else {
            throw AssetConversionOperationError.runtimeError("Asset in state not found")
        }

        guard let assetOutState = remoteState.assetOutState else {
            throw AssetConversionOperationError.runtimeError("Asset out state not found")
        }

        guard assetInState.tradable.canSell(), assetOutState.tradable.canBuy() else {
            throw AssetConversionOperationError.tradeDisabled
        }

        return HydraOmnipoolApi.Params(
            assetInState: assetInState,
            assetOutState: assetOutState,
            assetInBalance: remoteState.assetInBalance ?? 0,
            assetOutBalance: remoteState.assetOutBalance ?? 0,
            assetFee: remoteState.assetOutFee?.assetFee ?? defaultFee.assetFee,
            protocolFee: remoteState.assetInFee?.protocolFee ?? defaultFee.protocolFee,
            maxSlipFee: remoteState.maxSlipFee ?? 0
        )
    }

    static func calculateQuote(
        for direction: AssetConversion.Direction,
        args: HydraOmnipoolApi.Params,
        amount: BigUInt,
        limits: HydraExchangeTradeLimits.PoolLimits
    ) throws -> BigUInt {
        switch direction {
        case .sell:
            let amountOut = try HydraOmnipoolApi.calculateOutGivenIn(for: args, amountIn: amount)

            try validateTradeLimits(
                direction: .sell,
                amountIn: amount,
                amountOut: amountOut,
                args: args,
                limits: limits
            )

            return amountOut
        case .buy:
            let amountIn = try HydraOmnipoolApi.calculateInGivenOut(for: args, amountOut: amount)

            try validateTradeLimits(
                direction: .buy,
                amountIn: amountIn,
                amountOut: amount,
                args: args,
                limits: limits
            )

            return amountIn
        }
    }

    /// The Omnipool cap needs a probe through the pool math, which `HydraExchangeTradeLimits` keeps out
    /// of its validators so they stay pure arithmetic. So the probe runs here instead — only on a quote
    /// that has already been rejected, which is what keeps it off the happy path (NFR-1). Every other
    /// failure, a missing ratio included, propagates untouched.
    private static func validateTradeLimits(
        direction: AssetConversion.Direction,
        amountIn: BigUInt,
        amountOut: BigUInt,
        args: HydraOmnipoolApi.Params,
        limits: HydraExchangeTradeLimits.PoolLimits
    ) throws {
        do {
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: amountIn,
                amountOut: amountOut,
                reserveIn: args.assetInBalance,
                reserveOut: args.assetOutBalance,
                limits: limits
            )
        } catch HydraExchangeTradeLimitError.exceedsPoolTradeLimit {
            let cap = try HydraExchangeTradeLimits.omnipoolCap(
                direction: direction,
                params: args,
                limits: limits
            )

            throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit(
                cap.map {
                    HydraExchangePoolTradeCap(
                        maxGivenAmount: $0,
                        minTradingLimit: limits.minTradingLimit,
                        limitedAsset: nil
                    )
                }
            )
        }
    }
}

extension HydraOmnipoolQuoteFactory {
    func quote(for args: HydraExchange.QuoteArgs) -> CompoundOperationWrapper<BigUInt> {
        let remotePair = HydraDx.RemoteSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

        let constantsWrapper = createPalletConstantsWrapper()

        let calculateOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let constants = try constantsWrapper.targetOperation.extractNoCancellableResultData()

            let apiParams = try self.deriveApiParams(from: quoteState, defaultFee: constants.defaultFee)

            return try Self.calculateQuote(
                for: args.direction,
                args: apiParams,
                amount: args.amount,
                limits: constants.limits
            )
        }

        calculateOperation.addDependency(constantsWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + constantsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
