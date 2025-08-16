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
        dependingOn swapPairOperation: BaseOperation<HydraDx.SwapPair>
    ) -> CompoundOperationWrapper<HydraDx.QuoteRemoteState> {
        OperationCombiningService<HydraDx.QuoteRemoteState>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: flowState.operationQueue)
        ) {
            let swapPair = try swapPairOperation.extractNoCancellableResultData()

            let remoteSwapPair = HydraDx.RemoteSwapPair(
                assetIn: swapPair.assetIn.remoteAssetId,
                assetOut: swapPair.assetOut.remoteAssetId
            )

            let quoteService = self.flowState.setupQuoteService(for: remoteSwapPair)

            let operation = quoteService.createFetchOperation()

            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    private func createQuoteStateWrapper(
        for remoteSwapPair: HydraDx.RemoteSwapPair
    ) -> CompoundOperationWrapper<HydraDx.QuoteRemoteState> {
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

    private func canTrade(assetIn: HydraOmnipool.AssetState, assetOut: HydraOmnipool.AssetState) -> Bool {
        assetIn.tradable.canSell() && assetOut.tradable.canBuy()
    }

    private func calculateSellQuote(
        for amount: BigUInt,
        remoteState: HydraDx.QuoteRemoteState,
        defaultFee: HydraDx.FeeEntry
    ) throws -> BigUInt {
        guard let assetInState = remoteState.assetInState else {
            throw AssetConversionOperationError.runtimeError("Asset in state not found")
        }

        guard let assetOutState = remoteState.assetOutState else {
            throw AssetConversionOperationError.runtimeError("Asset out state not found")
        }

        guard canTrade(assetIn: assetInState, assetOut: assetOutState) else {
            throw AssetConversionOperationError.tradeDisabled
        }

        let assetFee = BigRational.permillPercent(
            of: remoteState.assetOutFee?.assetFee ?? defaultFee.assetFee
        )

        let protocolFee = BigRational.permillPercent(
            of: remoteState.assetInFee?.protocolFee ?? defaultFee.protocolFee
        )

        let inHubReserve = assetInState.hubReserve
        let inReserve = remoteState.assetInBalance ?? 0

        let divider = inReserve + amount

        guard divider > 0 else {
            throw AssetConversionOperationError.runtimeError("Unexpected zero reserve")
        }

        let deltaHubReserveIn = (amount * inHubReserve) / divider

        let protocolFeeAmount = protocolFee.mul(value: deltaHubReserveIn)
        let deltaHubReserveOut = deltaHubReserveIn - protocolFeeAmount

        let outReserveHp = remoteState.assetOutBalance ?? 0
        let outHubReserveHp = assetOutState.hubReserve

        let deltaReserveOut = (deltaHubReserveOut * outReserveHp) / (outHubReserveHp + deltaHubReserveOut)

        guard let amountOut = BigUInt(1).sub(rational: assetFee)?.mul(value: deltaReserveOut) else {
            throw AssetConversionOperationError.runtimeError("Fee too big")
        }

        return amountOut
    }

    private func calculateBuyQuote(
        for amount: BigUInt,
        remoteState: HydraDx.QuoteRemoteState,
        defaultFee: HydraDx.FeeEntry
    ) throws -> BigUInt {
        guard let assetInState = remoteState.assetInState else {
            throw AssetConversionOperationError.runtimeError("Asset in state not found")
        }

        guard let assetOutState = remoteState.assetOutState else {
            throw AssetConversionOperationError.runtimeError("Asset out state not found")
        }

        guard canTrade(assetIn: assetInState, assetOut: assetOutState) else {
            throw AssetConversionOperationError.tradeDisabled
        }

        let assetFee = BigRational.permillPercent(
            of: remoteState.assetOutFee?.assetFee ?? defaultFee.assetFee
        )

        let protocolFee = BigRational.permillPercent(
            of: remoteState.assetInFee?.protocolFee ?? defaultFee.protocolFee
        )

        let outReserve = remoteState.assetOutBalance ?? 0
        guard let outReserveNoFee = BigUInt(1).sub(rational: assetFee)?.mul(value: outReserve) else {
            throw AssetConversionOperationError.runtimeError("Asset fee too big")
        }

        guard outReserveNoFee > amount else {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        let outHubReserve = assetOutState.hubReserve
        let deltaHubReserveOut = (outHubReserve * amount) / (outReserveNoFee - amount) + 1

        guard protocolFee.denominator > protocolFee.numerator else {
            throw AssetConversionOperationError.runtimeError("Protocol fee too big")
        }

        // deltaHubReserveOut = (1 - protocolFee) * deltaHubReserveIn
        let deltaHubReserveIn = (deltaHubReserveOut * protocolFee.denominator) /
            (protocolFee.denominator - protocolFee.numerator)

        let inReserveHp = remoteState.assetInBalance ?? 0
        let inHubReserveHp = assetInState.hubReserve

        guard inHubReserveHp > deltaHubReserveIn else {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        let amountIn = (inReserveHp * deltaHubReserveIn) / (inHubReserveHp - deltaHubReserveIn) + 1

        return amountIn
    }
}

extension HydraOmnipoolQuoteFactory {
    func quote(for args: HydraOmnipool.QuoteArgs) -> CompoundOperationWrapper<BigUInt> {
        let remotePair = HydraDx.RemoteSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(for: remotePair)

        let defaultFeeWrapper = createDefaultFeeWrapper()

        let calculateOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let defaultFee = try defaultFeeWrapper.targetOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                return try self.calculateSellQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    defaultFee: defaultFee
                )

            case .buy:
                return try self.calculateBuyQuote(
                    for: args.amount,
                    remoteState: quoteState,
                    defaultFee: defaultFee
                )
            }
        }

        calculateOperation.addDependency(defaultFeeWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = quoteStateWrapper.allOperations + defaultFeeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
