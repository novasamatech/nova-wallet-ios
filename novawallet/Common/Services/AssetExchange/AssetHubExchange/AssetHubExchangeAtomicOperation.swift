import Foundation
import Operation_iOS

enum AssetHubExchangeAtomicOperationError: Error {
    case noEventsInResult
}

final class AssetHubExchangeAtomicOperation {
    let host: AssetHubExchangeHostProtocol
    let edge: any AssetExchangableGraphEdge
    let operationArgs: AssetExchangeAtomicOperationArgs

    init(
        host: AssetHubExchangeHostProtocol,
        operationArgs: AssetExchangeAtomicOperationArgs,
        edge: any AssetExchangableGraphEdge
    ) {
        self.host = host
        self.operationArgs = operationArgs
        self.edge = edge
    }

    private func createFeeWrapper() -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let callArgs = AssetConversion.CallArgs(
            assetIn: edge.origin,
            amountIn: operationArgs.swapLimit.amountIn,
            assetOut: edge.destination,
            amountOut: operationArgs.swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: operationArgs.swapLimit.direction,
            slippage: operationArgs.swapLimit.slippage
        )

        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let feeWrapper = host.extrinsicOperationFactory.estimateFeeOperation({ builder in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try AssetHubExtrinsicConverter.addingOperation(
                to: builder,
                chain: self.host.chain,
                args: callArgs,
                codingFactory: codingFactory
            )
        }, payingIn: operationArgs.feeAsset)

        feeWrapper.addDependency(operations: [codingFactoryOperation])

        return feeWrapper.insertingHead(operations: [codingFactoryOperation])
    }
}

extension AssetHubExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let executeWrapper = OperationCombiningService<Balance>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let callArgs = AssetConversion.CallArgs(
                assetIn: self.edge.origin,
                amountIn: swapLimit.amountIn,
                assetOut: self.edge.destination,
                amountOut: swapLimit.amountOut,
                receiver: self.host.selectedAccount.accountId,
                direction: swapLimit.direction,
                slippage: swapLimit.slippage
            )

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let submittionWrapper = self.host.submissionMonitorFactory.submitAndMonitorWrapper(
                extrinsicBuilderClosure: { builder in
                    try AssetHubExtrinsicConverter.addingOperation(
                        to: builder,
                        chain: self.host.chain,
                        args: callArgs,
                        codingFactory: codingFactory
                    )
                },
                payingIn: self.operationArgs.feeAsset,
                signer: self.host.signingWrapper,
                matchingEvents: AssetConversionEventsMatching()
            )

            let codingFactoryOperation = self.host.runtimeService.fetchCoderFactoryOperation()

            let monitorOperation = ClosureOperation<Balance> {
                let submittionResult = try submittionWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                switch submittionResult.status {
                case let .success(executionResult):
                    let eventParser = AssetConversionEventParser(logger: self.host.logger)

                    self.host.logger.debug("Execution success: \(executionResult.interestedEvents)")

                    guard let amountOut = eventParser.extractDeposit(
                        from: executionResult.interestedEvents,
                        using: codingFactory
                    ) else {
                        throw AssetHubExchangeAtomicOperationError.noEventsInResult
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

        executeWrapper.addDependency(operations: [codingFactoryOperation])

        return executeWrapper.insertingHead(operations: [codingFactoryOperation])
    }

    func submitWrapper(
        for swapLimit: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<Void> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let callArgs = AssetConversion.CallArgs(
            assetIn: edge.origin,
            amountIn: swapLimit.amountIn,
            assetOut: edge.destination,
            amountOut: swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: swapLimit.direction,
            slippage: swapLimit.slippage
        )

        let submittionWrapper = host.submissionMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: { builder in
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                return try AssetHubExtrinsicConverter.addingOperation(
                    to: builder,
                    chain: self.host.chain,
                    args: callArgs,
                    codingFactory: codingFactory
                )
            },
            payingIn: operationArgs.feeAsset,
            signer: host.signingWrapper,
            matchingEvents: nil
        )

        submittionWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<Void> {
            _ = try submittionWrapper.targetOperation.extractNoCancellableResultData()
            return
        }

        mappingOperation.addDependency(submittionWrapper.targetOperation)

        return submittionWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
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
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let amountOut = try amountOutClosure()

            return self.edge.quote(amount: amountOut, direction: .buy)
        }
    }

    var swapLimit: AssetExchangeSwapLimit {
        operationArgs.swapLimit
    }
}
