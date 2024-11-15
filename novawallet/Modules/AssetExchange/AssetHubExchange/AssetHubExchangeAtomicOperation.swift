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
        // TODO: Check whether we need to change direction
        let callArgs = AssetConversion.CallArgs(
            assetIn: edge.origin,
            amountIn: operationArgs.swapLimit.amountIn,
            assetOut: edge.destination,
            amountOut: operationArgs.swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: operationArgs.swapLimit.direction,
            slippage: operationArgs.swapLimit.slippage,
            context: nil
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
    func executeWrapper(
        for amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let executeWrapper = OperationCombiningService<Balance>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let amount = try amountClosure()

            let callArgs = AssetConversion.CallArgs(
                assetIn: self.edge.origin,
                amountIn: amount,
                assetOut: self.edge.destination,
                amountOut: self.operationArgs.swapLimit.amountOut,
                receiver: self.host.selectedAccount.accountId,
                direction: self.operationArgs.swapLimit.direction,
                slippage: self.operationArgs.swapLimit.slippage,
                context: nil
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

                switch submittionResult {
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
