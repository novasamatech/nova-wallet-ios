import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraOmnipoolQuoteFactory {
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

    private func createDefaultFeeWrapper() -> CompoundOperationWrapper<HydraDx.FeeEntry> {
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

        let mergeOperation = ClosureOperation<HydraDx.FeeEntry> {
            let assetFee = try assetFeeOperation.extractNoCancellableResultData().minFee
            let protocolFee = try protocolFeeOperation.extractNoCancellableResultData().minFee

            return HydraDx.FeeEntry(assetFee: assetFee, protocolFee: protocolFee)
        }

        mergeOperation.addDependency(assetFeeOperation)
        mergeOperation.addDependency(protocolFeeOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [coderFactoryOperation, assetFeeOperation, protocolFeeOperation]
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

    private func calculateQuote(
        for direction: AssetConversion.Direction,
        args: HydraOmnipoolApi.Params,
        amount: BigUInt
    ) throws -> BigUInt {
        switch direction {
        case .sell:
            return try HydraOmnipoolApi.calculateOutGivenIn(for: args, amountIn: amount)
        case .buy:
            return try HydraOmnipoolApi.calculateInGivenOut(for: args, amountOut: amount)
        }
    }
}

extension HydraOmnipoolQuoteFactory {
    func quote(for args: HydraExchange.QuoteArgs) -> CompoundOperationWrapper<BigUInt> {
        let remotePair = HydraDx.RemoteSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

        let defaultFeeWrapper = createDefaultFeeWrapper()

        let calculateOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let defaultFee = try defaultFeeWrapper.targetOperation.extractNoCancellableResultData()

            let apiParams = try self.deriveApiParams(from: quoteState, defaultFee: defaultFee)

            return try self.calculateQuote(
                for: args.direction,
                args: apiParams,
                amount: args.amount
            )
        }

        calculateOperation.addDependency(defaultFeeWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + defaultFeeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
