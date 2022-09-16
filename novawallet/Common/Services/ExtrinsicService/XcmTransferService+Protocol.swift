import Foundation
import RobinHood

typealias XcmTrasferFeeResult = Result<FeeWithWeight, Error>
typealias XcmTransferEstimateFeeClosure = (XcmTrasferFeeResult) -> Void

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
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    func estimateDestinationTransferFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    func estimateReserveTransferFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    )

    // Note: weight of the result contains max between reserve and destination weights
    func estimateCrossChainFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
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
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let unweighted = request.unweighted
            let maxWeight = request.maxWeight

            let callBuilderWrapper = createTransferWrapper(
                request: unweighted,
                xcmTransfers: xcmTransfers,
                maxWeight: maxWeight
            )

            let chainAccount = wallet.fetch(for: unweighted.origin.chain.accountRequest())
            let operationFactory = try createOperationFactory(for: unweighted.origin.chain, chainAccount: chainAccount)

            let feeWrapper = operationFactory.estimateFeeOperation { builder in
                let callClosure = try callBuilderWrapper.targetOperation.extractNoCancellableResultData().0
                return try callClosure(builder)
            }

            feeWrapper.addDependency(wrapper: callBuilderWrapper)

            feeWrapper.targetOperation.completionBlock = {
                switch feeWrapper.targetOperation.result {
                case let .success(dispatchInfo):
                    if let feeWithWeight = FeeWithWeight(dispatchInfo: dispatchInfo) {
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .success(feeWithWeight))
                    } else {
                        let error = CommonError.dataCorruption
                        callbackClosureIfProvided(completionClosure, queue: queue, result: .failure(error))
                    }
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

    func estimateDestinationTransferFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
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

    func estimateReserveTransferFee(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
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
        completion completionClosure: @escaping XcmTransferEstimateFeeClosure
    ) {
        do {
            let feeMessages = try xcmFactory.createWeightMessages(
                from: request.origin,
                reserve: request.reserve,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let destMsg = feeMessages.destination
            let destWrapper = createDestinationFeeWrapper(for: destMsg, request: request, xcmTransfers: xcmTransfers)

            var dependencies = destWrapper.allOperations

            let optReserveWrapper: CompoundOperationWrapper<FeeWithWeight>?

            if request.isNonReserveTransfer, let reserveMessage = feeMessages.reserve {
                let wrapper = createReserveFeeWrapper(
                    for: reserveMessage,
                    request: request,
                    xcmTransfers: xcmTransfers
                )

                dependencies.append(contentsOf: wrapper.allOperations)

                optReserveWrapper = wrapper
            } else {
                optReserveWrapper = nil
            }

            let mergeOperation = ClosureOperation<FeeWithWeight> {
                let destFeeWeight = try destWrapper.targetOperation.extractNoCancellableResultData()
                let optReserveFeeWeight = try optReserveWrapper?.targetOperation.extractNoCancellableResultData()

                if let reserveFeeWeight = optReserveFeeWeight {
                    let fee = destFeeWeight.fee + reserveFeeWeight.fee
                    let weight = max(destFeeWeight.weight, reserveFeeWeight.weight)
                    return FeeWithWeight(fee: fee, weight: weight)
                } else {
                    return destFeeWeight
                }
            }

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

            let operationFactory = try createOperationFactory(
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
