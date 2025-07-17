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
        for swapLimit: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        guard let assetIn, let assetOut else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        return OperationCombiningService<HydraExchangeSwapParams>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let callArgs = AssetConversion.CallArgs(
                assetIn: assetIn,
                amountIn: swapLimit.amountIn,
                assetOut: assetOut,
                amountOut: swapLimit.amountOut,
                receiver: self.host.selectedAccount.accountId,
                direction: swapLimit.direction,
                slippage: swapLimit.slippage
            )

            let routeComponents = self.edges.map(\.routeComponent)
            let route = HydraDx.RemoteSwapRoute(components: routeComponents)

            return self.host.extrinsicParamsFactory.createOperationWrapper(for: route, callArgs: callArgs)
        }
    }

    private func createFeeWrapper() -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let paramsWrapper = createExtrinsicParamsWrapper(for: operationArgs.swapLimit)

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
    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance> {
        let paramsWrapper = createExtrinsicParamsWrapper(for: swapLimit)

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

                switch submittionResult.status {
                case let .success(executionResult):
                    let eventParser = AssetsHydraExchangeDepositParser(logger: self.host.logger)

                    self.host.logger.debug("Execution success: \(executionResult.interestedEvents)")

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

    func submitWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Void> {
        let paramsWrapper = createExtrinsicParamsWrapper(for: swapLimit)

        let executionWrapper = OperationCombiningService<Void>.compoundNonOptionalWrapper(
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
                matchingEvents: nil
            )

            let mappingOperation = ClosureOperation<Void> {
                _ = try submittionWrapper.targetOperation.extractNoCancellableResultData()
                return
            }

            mappingOperation.addDependency(submittionWrapper.targetOperation)

            return submittionWrapper.insertingTail(operation: mappingOperation)
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

    func requiredAmountToGetAmountOut(
        _ amountOutClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        let quoteWrapper: CompoundOperationWrapper<Balance>? = edges.reversed().reduce(nil) { prevWrapper, edge in
            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: self.host.operationQueue)
            ) {
                if let prevWrapper {
                    let amountOut = try prevWrapper.targetOperation.extractNoCancellableResultData()
                    return edge.quote(amount: amountOut, direction: .buy)
                } else {
                    let amountOut = try amountOutClosure()
                    return edge.quote(amount: amountOut, direction: .buy)
                }
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)

                return quoteWrapper.insertingHead(operations: prevWrapper.allOperations)
            } else {
                return quoteWrapper
            }
        }

        guard let quoteWrapper else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        return quoteWrapper
    }

    var swapLimit: AssetExchangeSwapLimit {
        operationArgs.swapLimit
    }
}
