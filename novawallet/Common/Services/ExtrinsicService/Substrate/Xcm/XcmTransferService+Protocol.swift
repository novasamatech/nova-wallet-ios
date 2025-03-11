import Foundation
import Operation_iOS
import BigInt

typealias XcmTransferOriginFeeResult = Result<ExtrinsicFeeProtocol, Error>
typealias XcmTransferOriginFeeClosure = (XcmTransferOriginFeeResult) -> Void

typealias XcmTransferCrosschainFeeResult = Result<XcmFeeModelProtocol, Error>
typealias XcmTransferCrosschainFeeClosure = (XcmTransferCrosschainFeeResult) -> Void

struct XcmSubmitExtrinsic {
    let txHash: String
    let callPath: CallCodingPath
}

typealias XcmSubmitExtrinsicResult = Result<XcmSubmitExtrinsic, Error>
typealias XcmExtrinsicSubmitClosure = (XcmSubmitExtrinsicResult) -> Void

protocol XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferOriginFeeClosure
    )

    func estimateDestinationExecutionFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    )

    func estimateReserveExecutionFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    )

    // Note: weight of the result contains max between reserve and destination weights
    func estimateCrossChainFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    )

    func submit(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    )
}

extension XcmTransferService: XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferOriginFeeClosure
    ) {
        do {
            let unweighted = request.unweighted
            let maxWeight = request.maxWeight

            let callBuilderWrapper = createTransferWrapper(
                request: unweighted,
                xcmTransfers: xcmTransfers,
                maxWeight: maxWeight
            )

            guard let chainAccount = wallet.fetch(for: unweighted.origin.chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let operationFactory = try createExtrinsicOperationFactory(
                for: unweighted.origin.chain,
                chainAccount: chainAccount
            )

            let feeWrapper = operationFactory.estimateFeeOperation({ builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData().0
                return try callClosure(builder)
            }, payingIn: request.originFeeAsset)

            feeWrapper.addDependency(wrapper: callBuilderWrapper)

            let totalWrapper = feeWrapper.insertingHead(operations: callBuilderWrapper.allOperations)

            execute(
                wrapper: totalWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: queue,
                callbackClosure: completionClosure
            )

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateDestinationExecutionFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    ) {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                return self.createDestinationFeeWrapper(
                    for: feeMessages.destination,
                    request: request,
                    xcmTransfers: xcmTransfers
                )
            }

            feeWrapper.addDependency(wrapper: versionWrapper)

            let totalWrapper = feeWrapper.insertingHead(operations: versionWrapper.allOperations)

            execute(
                wrapper: totalWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: queue,
                callbackClosure: completionClosure
            )

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateReserveExecutionFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    ) {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let versionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(for: runtimeProvider)

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let version = try versionWrapper.targetOperation.extractNoCancellableResultData()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                guard let reserveMessage = feeMessages.reserve else {
                    throw XcmTransferServiceError.reserveFeeNotAvailable
                }

                return self.createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    xcmTransfers: xcmTransfers
                )
            }

            feeWrapper.addDependency(wrapper: versionWrapper)

            let totalWrapper = feeWrapper.insertingHead(operations: versionWrapper.allOperations)

            execute(
                wrapper: totalWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: queue,
                callbackClosure: completionClosure
            )

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func estimateCrossChainFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    ) {
        do {
            let destinationRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.destination.chain.chainId
            )

            let reserveRuntimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: request.reserve.chain.chainId
            )

            let destinationVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
                for: destinationRuntimeProvider
            )

            let reserveVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
                for: reserveRuntimeProvider
            )

            let feeWrapper: CompoundOperationWrapper<XcmFeeModelProtocol>
            feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let destinationVersion = try destinationVersionWrapper.targetOperation.extractNoCancellableResultData()
                let reserveVersion = try reserveVersionWrapper.targetOperation.extractNoCancellableResultData()

                let version = [destinationVersion, reserveVersion]
                    .compactMap { $0 }
                    .max()

                let params = XcmWeightMessagesParams(
                    chainAsset: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    xcmTransfers: xcmTransfers
                )

                let feeMessages = try self.xcmWeightMessagesFactory.createWeightMessages(
                    from: params,
                    version: version
                )

                let executionFeeWrapper = self.createExecutionFeeWrapper(
                    request: request,
                    xcmTransfers: xcmTransfers,
                    feeMessages: feeMessages
                )

                let deliveryFeeWrapper = self.createDeliveryFeeWrapper(
                    request: request,
                    xcmTransfers: xcmTransfers,
                    feeMessages: feeMessages
                )

                let mergeOperation = ClosureOperation<XcmFeeModelProtocol> {
                    let executionFee = try executionFeeWrapper.targetOperation.extractNoCancellableResultData()
                    let deliveryFee = try deliveryFeeWrapper.targetOperation.extractNoCancellableResultData()

                    return XcmFeeModel.combine(executionFee, deliveryFee)
                }

                mergeOperation.addDependency(deliveryFeeWrapper.targetOperation)
                mergeOperation.addDependency(executionFeeWrapper.targetOperation)

                return deliveryFeeWrapper
                    .insertingHead(operations: executionFeeWrapper.allOperations)
                    .insertingTail(operation: mergeOperation)
            }

            feeWrapper.addDependency(wrapper: destinationVersionWrapper)
            feeWrapper.addDependency(wrapper: reserveVersionWrapper)

            let totalWrapper = feeWrapper
                .insertingHead(operations: destinationVersionWrapper.allOperations)
                .insertingHead(operations: reserveVersionWrapper.allOperations)

            execute(
                wrapper: totalWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: queue,
                callbackClosure: completionClosure
            )

        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }

    func submit(
        request: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    ) {
        do {
            let callBuilderWrapper = createTransferWrapper(
                request: request.unweighted,
                xcmTransfers: xcmTransfers,
                maxWeight: request.maxWeight
            )

            guard let chainAccount = wallet.fetch(for: request.unweighted.origin.chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let operationFactory = try createExtrinsicOperationFactory(
                for: request.unweighted.origin.chain,
                chainAccount: chainAccount
            )

            let submitWrapper = operationFactory.submit({ builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData().0
                return try callClosure(builder)
            }, signer: signer, payingIn: request.originFeeAsset)

            submitWrapper.addDependency(wrapper: callBuilderWrapper)

            submitWrapper.targetOperation.completionBlock = {
                do {
                    let txHash = try submitWrapper.targetOperation.extractNoCancellableResultData()
                    let callPath = try callBuilderWrapper.targetOperation.extractNoCancellableResultData().1
                    let extrinsicResult = XcmSubmitExtrinsic(txHash: txHash, callPath: callPath)

                    callbackClosureIfProvided(completionClosure, queue: queue, result: .success(extrinsicResult))
                } catch {
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            let operations = callBuilderWrapper.allOperations + submitWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
        }
    }
}
