import Foundation
import Operation_iOS
import BigInt

final class HydraAaveSwapQuoteFactory {
    let flowState: HydraAaveFlowState

    init(flowState: HydraAaveFlowState) {
        self.flowState = flowState
    }
}

private extension HydraAaveSwapQuoteFactory {
    func createQuoteStateWrapper(
        for remoteSwapPair: HydraDx.RemoteSwapPair
    ) -> CompoundOperationWrapper<HydraAave.PoolData> {
        let quoteService = flowState.setupQuoteService(for: remoteSwapPair)

        let operation = quoteService.createFetchOperation()

        return CompoundOperationWrapper(targetOperation: operation)
    }

    // the rate is always 1:1 but need to check liquidity first
    private func calculateAmount(
        for assetIdOut: HydraDx.AssetId,
        amount: BigUInt,
        remoteState: HydraAave.PoolData
    ) throws -> Balance {
        guard
            let liquidityOut = remoteState.findPoolTokenLiquidity(for: assetIdOut),
            amount <= liquidityOut else {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return amount
    }
}

extension HydraAaveSwapQuoteFactory {
    func quote(for args: HydraAave.QuoteArgs) -> CompoundOperationWrapper<Balance> {
        let remotePair = HydraDx.RemoteSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

        let calculateOperation = ClosureOperation<Balance> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                return try self.calculateAmount(
                    for: remotePair.assetIn,
                    amount: args.amount,
                    remoteState: quoteState
                )

            case .buy:
                return try self.calculateAmount(
                    for: remotePair.assetOut,
                    amount: args.amount,
                    remoteState: quoteState
                )
            }
        }

        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        return quoteStateWrapper.insertingTail(operation: calculateOperation)
    }
}
