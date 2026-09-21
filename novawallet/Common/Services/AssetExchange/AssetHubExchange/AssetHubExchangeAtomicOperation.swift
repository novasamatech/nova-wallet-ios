import Foundation
import Operation_iOS

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
}

extension AssetHubExchangeAtomicOperation {
    static func guaranteedNetAmountOut(for params: AssetHubExchangeSwapParams) -> Balance {
        let palletBound: Balance

        switch params.swap {
        case let .exactIn(call):
            palletBound = call.amountOutMin
        case let .exactOut(call):
            palletBound = call.amountOut
        }

        return palletBound.subtractOrZero(params.commission?.amount ?? 0)
    }
}

private extension AssetHubExchangeAtomicOperation {
    func createParamsWrapper(
        for swapLimit: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<AssetHubExchangeSwapParams> {
        let callArgs = AssetConversion.CallArgs(
            assetIn: edge.origin,
            amountIn: swapLimit.amountIn,
            assetOut: edge.destination,
            amountOut: swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: swapLimit.direction,
            slippage: swapLimit.slippage
        )

        return host.extrinsicParamsFactory.createOperationWrapper(
            callArgs: callArgs,
            commission: operationArgs.commission
        )
    }

    func createSubmissionWrapper(
        for params: AssetHubExchangeSwapParams
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        host.submissionMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: { builder in
                try AssetHubExchangeExtrinsicConverter.addingOperation(from: params, builder: builder)
            },
            payingIn: operationArgs.feeAsset,
            signer: host.signingWrapper,
            matchingEvents: AssetConversionEventsMatching(commissionStorageInfo: params.commission?.assetStorageInfo)
        )
    }

    func extractOrigin(from sender: ExtrinsicSenderResolution) -> AccountId {
        switch sender {
        case let .current(account):
            return account.accountId
        case let .delegate(resolution):
            return resolution.delegatedAccount.accountId
        }
    }

    func createMeasuringWrapper(
        for params: AssetHubExchangeSwapParams,
        submissionWrapper: CompoundOperationWrapper<ExtrinsicMonitorSubmission>
    ) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<Balance> {
            let submission = try submissionWrapper.targetOperation.extractNoCancellableResultData()

            switch submission.status {
            case let .failure(failure):
                throw failure.error
            case let .success(success):
                let parser = AssetConversionEventParser(logger: self.host.logger)

                do {
                    let amountOut = try parser.extractDeposit(
                        from: success.interestedEvents,
                        params: params,
                        origin: self.extractOrigin(from: submission.extrinsicSubmittedModel.sender),
                        using: codingFactoryOperation.extractNoCancellableResultData()
                    )

                    self.host.logger.debug("Arrived amount: \(String(amountOut))")

                    return amountOut
                } catch {
                    let guaranteed = Self.guaranteedNetAmountOut(for: params)

                    self.host.logger.error(
                        "Swap executed but output unverified (\(error)), using \(String(guaranteed))"
                    )

                    return guaranteed
                }
            }
        }

        mappingOperation.addDependency(submissionWrapper.targetOperation)
        mappingOperation.addDependency(codingFactoryOperation)

        return submissionWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}

extension AssetHubExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        let paramsWrapper = createParamsWrapper(for: operationArgs.swapLimit)

        let feeWrapper: CompoundOperationWrapper<ExtrinsicFeeProtocol>
        feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            return self.host.extrinsicOperationFactory.estimateFeeOperation({ builder in
                try AssetHubExchangeExtrinsicConverter.addingOperation(from: params, builder: builder)
            }, payingIn: self.operationArgs.feeAsset)
        }

        feeWrapper.addDependency(wrapper: paramsWrapper)

        let mappingOperation = ClosureOperation<AssetExchangeOperationFee> {
            let extrinsicFee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeOperationFee(extrinsicFee: extrinsicFee, args: self.operationArgs)
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: paramsWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func executeWrapper(for swapLimit: AssetExchangeSwapLimit) -> CompoundOperationWrapper<Balance> {
        let paramsWrapper = createParamsWrapper(for: swapLimit)

        let executionWrapper: CompoundOperationWrapper<Balance>
        executionWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            return self.createMeasuringWrapper(
                for: params,
                submissionWrapper: self.createSubmissionWrapper(for: params)
            )
        }

        executionWrapper.addDependency(wrapper: paramsWrapper)

        return executionWrapper.insertingHead(operations: paramsWrapper.allOperations)
    }

    func submitWrapper(
        for swapLimit: AssetExchangeSwapLimit
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        let paramsWrapper = createParamsWrapper(for: swapLimit)

        let submissionWrapper: CompoundOperationWrapper<ExtrinsicSubmittedModel>
        submissionWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            let monitorWrapper = self.createSubmissionWrapper(for: params)

            let measuringWrapper = self.createMeasuringWrapper(
                for: params,
                submissionWrapper: monitorWrapper
            )

            let mappingOperation = ClosureOperation<ExtrinsicSubmittedModel> {
                let submission = try monitorWrapper.targetOperation.extractNoCancellableResultData()

                switch submission.status {
                case let .failure(failure):
                    throw failure.error
                case .success:
                    // a delayed call is only approved at this point, so it has no execution events yet
                    if !submission.extrinsicSubmittedModel.sender.delayedCallExecution() {
                        _ = try measuringWrapper.targetOperation.extractNoCancellableResultData()
                    }

                    return submission.extrinsicSubmittedModel
                }
            }

            mappingOperation.addDependency(monitorWrapper.targetOperation)
            mappingOperation.addDependency(measuringWrapper.targetOperation)

            return measuringWrapper.insertingTail(operation: mappingOperation)
        }

        submissionWrapper.addDependency(wrapper: paramsWrapper)

        return submissionWrapper.insertingHead(operations: paramsWrapper.allOperations)
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
