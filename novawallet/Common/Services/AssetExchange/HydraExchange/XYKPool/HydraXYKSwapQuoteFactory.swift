import Foundation
import Operation_iOS
import BigInt

final class HydraXYKSwapQuoteFactory {
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
        guard
            let balanceIn = remoteState.assetInBalance,
            let balanceOut = remoteState.assetOutBalance else {
            throw AssetConversionOperationError.runtimeError("Pool balance not found")
        }

        let amountOut = try HydraXYKSwapApi.calculateOutGivenIn(
            for: balanceIn,
            balanceOut: balanceOut,
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
        guard
            let balanceIn = remoteState.assetInBalance,
            let balanceOut = remoteState.assetOutBalance else {
            throw AssetConversionOperationError.runtimeError("Pool balance not found")
        }

        let amountIn = try HydraXYKSwapApi.calculateInGivenOut(
            for: balanceIn,
            balanceOut: balanceOut,
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
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

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
