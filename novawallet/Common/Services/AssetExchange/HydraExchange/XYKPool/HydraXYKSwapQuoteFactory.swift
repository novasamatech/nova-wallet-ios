import Foundation
import Operation_iOS
import BigInt

final class HydraXYKSwapQuoteFactory {
    let flowState: HydraXYKFlowState

    init(flowState: HydraXYKFlowState) {
        self.flowState = flowState
    }

    func quoteStateWrapper(
        for remoteSwapPair: HydraDx.RemoteSwapPair
    ) -> CompoundOperationWrapper<HydraXYK.QuoteRemoteState> {
        let quoteService = flowState.setupQuoteService(for: remoteSwapPair)

        let operation = quoteService.createFetchOperation()

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createFeeParamsWrapper() -> CompoundOperationWrapper<HydraXYK.ExchangeFeeParams> {
        let coderFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let feeParamsOperation = StorageConstantOperation<HydraXYK.ExchangeFeeParams>.operation(
            path: HydraXYK.exchangeFeePath,
            dependingOn: coderFactoryOperation
        )

        feeParamsOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: feeParamsOperation,
            dependencies: [coderFactoryOperation]
        )
    }

    private func calculateSellQuote(
        for amount: BigUInt,
        remoteState: HydraXYK.QuoteRemoteState,
        feeParams: HydraXYK.ExchangeFeeParams
    ) throws -> BigUInt {
        let amountOut = try HydraXYKSwapApi.calculateOutGivenIn(
            for: remoteState.assetInBalance,
            balanceOut: remoteState.assetOutBalance,
            amountIn: amount
        )

        let fee = try HydraXYKSwapApi.calculaPoolFee(
            for: amountOut,
            feeNominator: feeParams.nominator,
            feeDenominator: feeParams.denominator
        )

        return amountOut > fee ? amountOut - fee : 0
    }

    private func calculateBuyQuote(
        for amount: BigUInt,
        remoteState: HydraXYK.QuoteRemoteState,
        feeParams: HydraXYK.ExchangeFeeParams
    ) throws -> BigUInt {
        let amountIn = try HydraXYKSwapApi.calculateInGivenOut(
            for: remoteState.assetInBalance,
            balanceOut: remoteState.assetOutBalance,
            amountOut: amount
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
        let quoteStateWrapper = quoteStateWrapper(for: remotePair)

        let feeParamsWrapper = createFeeParamsWrapper()

        let calculateOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let feeParams = try feeParamsWrapper.targetOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                return try self.calculateSellQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    feeParams: feeParams
                )

            case .buy:
                return try self.calculateBuyQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    feeParams: feeParams
                )
            }
        }

        calculateOperation.addDependency(feeParamsWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + feeParamsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}

extension HydraXYKSwapQuoteFactory {
    /// Answers the XYK pallet's `validate_sell` / `validate_buy` for one hop, and derives the cap in
    /// the same pass — the reserves are already in hand, so reporting costs no extra round trip.
    ///
    /// Static and reserve-driven so the arithmetic is testable without a flow state (NFR-2).
    static func tradeLimitVerdict(
        for amount: Balance,
        direction: AssetConversion.Direction,
        remoteState: HydraXYK.QuoteRemoteState,
        limits: HydraExchangeTradeLimits.PoolLimits
    ) throws -> AssetExchangeTradeLimitVerdict {
        let reserveIn = remoteState.assetInBalance
        let reserveOut = remoteState.assetOutBalance

        let exceeds: Bool
        let cap: Balance

        switch direction {
        case .sell:
            let amountOutPreFee = try HydraXYKSwapApi.calculateOutGivenIn(
                for: reserveIn,
                balanceOut: reserveOut,
                amountIn: amount
            )

            exceeds = try HydraExchangeTradeLimits.xykSellExceedsLimit(
                amountIn: amount,
                amountOutPreFee: amountOutPreFee,
                reserveIn: reserveIn,
                reserveOut: reserveOut,
                limits: limits
            )

            cap = try HydraExchangeTradeLimits.maxSellAmountIn(
                reserveIn: reserveIn,
                reserveOut: reserveOut,
                limits: limits
            )
        case .buy:
            let amountInPreFee = try HydraXYKSwapApi.calculateInGivenOut(
                for: reserveIn,
                balanceOut: reserveOut,
                amountOut: amount
            )

            exceeds = try HydraExchangeTradeLimits.xykBuyExceedsLimit(
                amountOut: amount,
                amountInPreFee: amountInPreFee,
                reserveIn: reserveIn,
                reserveOut: reserveOut,
                limits: limits
            )

            cap = try HydraExchangeTradeLimits.maxBuyAmountOut(
                reserveIn: reserveIn,
                reserveOut: reserveOut,
                limits: limits
            )
        }

        guard exceeds else {
            return .withinLimit
        }

        return .exceeds(
            .init(maxGivenAmount: cap, minTradingLimit: limits.minTradingLimit)
        )
    }
}
