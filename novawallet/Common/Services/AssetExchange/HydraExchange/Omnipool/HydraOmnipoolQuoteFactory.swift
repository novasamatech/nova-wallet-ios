import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraOmnipoolQuoteFactory {
    private struct PalletConstants {
        let defaultFee: HydraDx.FeeEntry
        let ratios: HydraExchangeTradeLimits.Ratios
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

        let ratiosWrapper = HydraExchangeTradeLimits.createRatiosWrapper(
            for: .omnipool,
            dependingOn: coderFactoryOperation
        )

        let mergeOperation = ClosureOperation<PalletConstants> {
            let assetFee = try assetFeeOperation.extractNoCancellableResultData().minFee
            let protocolFee = try protocolFeeOperation.extractNoCancellableResultData().minFee

            let ratios = try ratiosWrapper.targetOperation.extractNoCancellableResultData()

            return PalletConstants(
                defaultFee: HydraDx.FeeEntry(assetFee: assetFee, protocolFee: protocolFee),
                ratios: ratios
            )
        }

        mergeOperation.addDependency(assetFeeOperation)
        mergeOperation.addDependency(protocolFeeOperation)
        mergeOperation.addDependency(ratiosWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [
                coderFactoryOperation,
                assetFeeOperation,
                protocolFeeOperation
            ] + ratiosWrapper.allOperations
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
        ratios: HydraExchangeTradeLimits.Ratios
    ) throws -> BigUInt {
        switch direction {
        case .sell:
            let amountOut = try HydraOmnipoolApi.calculateOutGivenIn(for: args, amountIn: amount)

            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: amount,
                amountOut: amountOut,
                reserveIn: args.assetInBalance,
                reserveOut: args.assetOutBalance,
                ratios: ratios
            )

            return amountOut
        case .buy:
            let amountIn = try HydraOmnipoolApi.calculateInGivenOut(for: args, amountOut: amount)

            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: amountIn,
                amountOut: amount,
                reserveIn: args.assetInBalance,
                reserveOut: args.assetOutBalance,
                ratios: ratios
            )

            return amountIn
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
                ratios: constants.ratios
            )
        }

        calculateOperation.addDependency(constantsWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + constantsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
