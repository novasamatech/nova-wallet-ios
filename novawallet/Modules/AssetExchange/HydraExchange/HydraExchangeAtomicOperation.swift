import Foundation
import Operation_iOS

enum HydraExchangeAtomicOperationError: Error {
    case noRoute
    case noEventsInResult
}

final class HydraExchangeAtomicOperation {
    typealias Edge = AssetsHydraExchangeEdgeProtocol & AssetExchangableGraphEdge

    let host: HydraExchangeHostProtocol
    let edges: [any Edge]
    let operationArgs: AssetExchangeAtomicOperationArgs

    var assetIn: ChainAssetId? {
        edges.first?.origin
    }

    var assetOut: ChainAssetId? {
        edges.last?.destination
    }

    var chainId: ChainModel.Id? {
        assetIn?.chainId
    }

    init(
        host: HydraExchangeHostProtocol,
        operationArgs: AssetExchangeAtomicOperationArgs,
        edges: [any Edge]
    ) {
        self.host = host
        self.operationArgs = operationArgs
        self.edges = edges
    }

    private func createExtrinsicParamsWrapper(
        for amountInClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        guard let assetIn, let assetOut else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        return OperationCombiningService<HydraExchangeSwapParams>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let amountIn = try amountInClosure()
            let callArgs = AssetConversion.CallArgs(
                assetIn: assetIn,
                amountIn: amountIn,
                assetOut: assetOut,
                amountOut: self.operationArgs.swapLimit.amountOut,
                receiver: self.host.selectedAccount.accountId,
                direction: self.operationArgs.swapLimit.direction,
                slippage: self.operationArgs.swapLimit.slippage,
                context: nil
            )

            let routeComponents = self.edges.map(\.routeComponent)
            let route = HydraDx.RemoteSwapRoute(components: routeComponents)

            return self.host.extrinsicParamsFactory.createOperationWrapper(for: route, callArgs: callArgs)
        }
    }

    private func createFeeWrapper() -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let paramsWrapper = createExtrinsicParamsWrapper { self.operationArgs.swapLimit.amountIn }

        let feeWrapper = OperationCombiningService<ExtrinsicFeeProtocol>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            let feeWrapper = self.host.extrinsicOperationFactory.estimateFeeOperation({ builder in
                try HydraExchangeExtrinsicConverter.addingOperation(
                    from: params,
                    builder: builder
                )
            }, payingIn: self.operationArgs.feeAsset)

            return feeWrapper
        }

        feeWrapper.addDependency(wrapper: paramsWrapper)

        return feeWrapper.insertingHead(operations: paramsWrapper.allOperations)
    }
}

extension HydraExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for amountClosure: @escaping () throws -> Balance) -> CompoundOperationWrapper<Balance> {
        let paramsWrapper = createExtrinsicParamsWrapper(for: amountClosure)

        let executionWrapper = OperationCombiningService<Balance>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            let submittionWrapper = self.host.submissionMonitorFactory.submitAndMonitorWrapper(
                extrinsicBuilderClosure: { builder in
                    try HydraExchangeExtrinsicConverter.addingOperation(
                        from: params,
                        builder: builder
                    )
                },
                payingIn: self.operationArgs.feeAsset,
                signer: self.host.signingWrapper,
                matchingEvents: HydraSwapEventsMatcher()
            )

            let codingFactoryOperation = self.host.runtimeService.fetchCoderFactoryOperation()

            let monitorOperation = ClosureOperation<Balance> {
                let submittionResult = try submittionWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                switch submittionResult {
                case let .success(executionResult):
                    let eventParser = AssetsHydraExchangeDepositParser(logger: self.host.logger)

                    guard let amountOut = eventParser.extractDeposit(
                        from: executionResult.interestedEvents,
                        using: codingFactory
                    ) else {
                        throw HydraExchangeAtomicOperationError.noEventsInResult
                    }

                    self.host.logger.debug("Arrived amount: \(String(amountOut))")

                    return amountOut
                case let .failure(executionFailure):
                    throw executionFailure.error
                }
            }

            monitorOperation.addDependency(submittionWrapper.targetOperation)
            monitorOperation.addDependency(codingFactoryOperation)

            return submittionWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: monitorOperation)
        }

        executionWrapper.addDependency(wrapper: paramsWrapper)

        return executionWrapper.insertingHead(operations: paramsWrapper.allOperations)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        let feeWrapper = createFeeWrapper()

        let mappingOperation = ClosureOperation<AssetExchangeOperationFee> {
            let extrinsicFee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeOperationFee(extrinsicFee: extrinsicFee, args: self.operationArgs)
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper.insertingTail(operation: mappingOperation)
    }
}
