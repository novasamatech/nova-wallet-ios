import Foundation
import Operation_iOS
import BigInt

final class HydraXYKSwapQuoteFactory {
    private struct PalletConstants {
        let feeParams: HydraXYK.ExchangeFeeParams
        let ratios: HydraExchangeTradeLimits.Ratios
    }

    let flowState: HydraXYKFlowState

    init(flowState: HydraXYKFlowState) {
        self.flowState = flowState
    }

    private func createQuoteStateWrapper(
        for remoteSwapPair: HydraDx.RemoteSwapPair
    ) -> CompoundOperationWrapper<HydraXYK.QuoteRemoteState> {
        let quoteService = flowState.setupQuoteService(for: remoteSwapPair)

        let operation = quoteService.createFetchOperation()

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createPalletConstantsWrapper() -> CompoundOperationWrapper<PalletConstants> {
        let coderFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let feeParamsOperation = StorageConstantOperation<HydraXYK.ExchangeFeeParams>.operation(
            path: HydraXYK.exchangeFeePath,
            dependingOn: coderFactoryOperation
        )

        feeParamsOperation.addDependency(coderFactoryOperation)

        let ratiosWrapper = HydraExchangeTradeLimits.createRatiosWrapper(
            for: .xyk,
            dependingOn: coderFactoryOperation
        )

        let mergeOperation = ClosureOperation<PalletConstants> {
            let feeParams = try feeParamsOperation.extractNoCancellableResultData()
            let ratios = try ratiosWrapper.targetOperation.extractNoCancellableResultData()

            return PalletConstants(feeParams: feeParams, ratios: ratios)
        }

        mergeOperation.addDependency(feeParamsOperation)
        mergeOperation.addDependency(ratiosWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [coderFactoryOperation, feeParamsOperation] + ratiosWrapper.allOperations
        )
    }

    static func calculateSellQuote(
        for amount: BigUInt,
        remoteState: HydraXYK.QuoteRemoteState,
        feeParams: HydraXYK.ExchangeFeeParams,
        ratios: HydraExchangeTradeLimits.Ratios
    ) throws -> BigUInt {
        let amountOut = try HydraXYKSwapApi.calculateOutGivenIn(
            for: remoteState.assetInBalance,
            balanceOut: remoteState.assetOutBalance,
            amountIn: amount
        )

        try HydraExchangeTradeLimits.validateXYKSell(
            amountIn: amount,
            amountOutPreFee: amountOut,
            reserveIn: remoteState.assetInBalance,
            reserveOut: remoteState.assetOutBalance,
            ratios: ratios
        )

        let fee = try HydraXYKSwapApi.calculaPoolFee(
            for: amountOut,
            feeNominator: feeParams.nominator,
            feeDenominator: feeParams.denominator
        )

        return amountOut > fee ? amountOut - fee : 0
    }

    static func calculateBuyQuote(
        for amount: BigUInt,
        remoteState: HydraXYK.QuoteRemoteState,
        feeParams: HydraXYK.ExchangeFeeParams,
        ratios: HydraExchangeTradeLimits.Ratios
    ) throws -> BigUInt {
        let amountIn = try HydraXYKSwapApi.calculateInGivenOut(
            for: remoteState.assetInBalance,
            balanceOut: remoteState.assetOutBalance,
            amountOut: amount
        )

        try HydraExchangeTradeLimits.validateXYKBuy(
            amountOut: amount,
            amountInPreFee: amountIn,
            reserveIn: remoteState.assetInBalance,
            reserveOut: remoteState.assetOutBalance,
            ratios: ratios
        )

        let fee = try HydraXYKSwapApi.calculaPoolFee(
            for: amountIn,
            feeNominator: feeParams.nominator,
            feeDenominator: feeParams.denominator
        )

        return amountIn + fee
    }
}

extension HydraXYKSwapQuoteFactory {
    func quote(for args: HydraExchange.QuoteArgs) -> CompoundOperationWrapper<BigUInt> {
        let remotePair = HydraDx.RemoteSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

        let constantsWrapper = createPalletConstantsWrapper()

        let calculateOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let constants = try constantsWrapper.targetOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                return try Self.calculateSellQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    feeParams: constants.feeParams,
                    ratios: constants.ratios
                )

            case .buy:
                return try Self.calculateBuyQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    feeParams: constants.feeParams,
                    ratios: constants.ratios
                )
            }
        }

        calculateOperation.addDependency(constantsWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + constantsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
