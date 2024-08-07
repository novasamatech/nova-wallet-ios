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

            let feeWrapper = operationFactory.estimateFeeOperation { builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData().0
                return try callClosure(builder)
            }

            feeWrapper.addDependency(wrapper: callBuilderWrapper)

            feeWrapper.targetOperation.completionBlock = {
                switch feeWrapper.targetOperation.result {
                case let .success(fee):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .success(fee))
                case let .failure(error):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            let operations = callBuilderWrapper.allOperations + feeWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)
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
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let wrapper = createDestinationFeeWrapper(
                for: feeMessages.destination,
                request: request,
                xcmTransfers: xcmTransfers
            )

            wrapper.targetOperation.completionBlock = {
                switch wrapper.targetOperation.result {
                case let .some(result):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

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
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            if let reserveMessage = feeMessages.reserve {
                let wrapper = createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    xcmTransfers: xcmTransfers
                )

                wrapper.targetOperation.completionBlock = {
                    switch wrapper.targetOperation.result {
                    case let .some(result):
                        callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                    }
                }

                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
            } else {
                callbackClosureIfProvided(
                    completionClosure,
                    queue: queue,
                    result: .failure(XcmTransferServiceError.reserveFeeNotAvailable)
                )
            }
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
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let executionFeeWrapper = createExecutionFeeWrapper(
                request: request,
                xcmTransfers: xcmTransfers,
                feeMessages: feeMessages
            )

            let deliveryFeeWrapper = createDeliveryFeeWrapper(
                request: request,
                xcmTransfers: xcmTransfers,
                feeMessages: feeMessages
            )

            let mergeOperation = ClosureOperation<XcmFeeModelProtocol> {
                let executionFee = try executionFeeWrapper.targetOperation.extractNoCancellableResultData()
                let deliveryFee = try deliveryFeeWrapper.targetOperation.extractNoCancellableResultData()

                return XcmFeeModel.combine(executionFee, deliveryFee)
            }

            let dependencies = executionFeeWrapper.allOperations + deliveryFeeWrapper.allOperations

            dependencies.forEach { mergeOperation.addDependency($0) }

            mergeOperation.completionBlock = {
                switch mergeOperation.result {
                case let .some(result):
                    callbackClosureIfProvided(completionClosure, queue: queue, result: result)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                }
            }

            operationQueue.addOperations(dependencies + [mergeOperation], waitUntilFinished: false)

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
            }, signer: signer)

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
