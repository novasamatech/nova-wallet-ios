import Foundation
import Operation_iOS
import BigInt

typealias XcmTransferOriginFeeResult = Result<ExtrinsicFeeProtocol, Error>
typealias XcmTransferOriginFeeClosure = (XcmTransferOriginFeeResult) -> Void

typealias XcmTransferCrosschainFeeResult = Result<XcmFeeModelProtocol, Error>
typealias XcmTransferCrosschainFeeClosure = (XcmTransferCrosschainFeeResult) -> Void

struct XcmSubmitExtrinsic {
    let submittedModel: ExtrinsicSubmittedModel
    let callPath: CallCodingPath
}

typealias XcmSubmitExtrinsicResult = Result<XcmSubmitExtrinsic, Error>
typealias XcmExtrinsicSubmitClosure = (XcmSubmitExtrinsicResult) -> Void

protocol XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferOriginFeeClosure
    )

    // Note: weight of the result contains max between reserve and destination weights
    func estimateCrossChainFee(
        request: XcmUnweightedTransferRequest,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    )

    func submit(
        request: XcmTransferRequest,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    )
}

extension XcmTransferService: XcmTransferServiceProtocol {
    func estimateOriginFee(
        request: XcmTransferRequest,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferOriginFeeClosure
    ) {
        do {
            let unweighted = request.unweighted

            let callBuilderWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: unweighted
            )

            guard let chainAccount = wallet.fetch(for: unweighted.originChain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let operationFactory = try createExtrinsicOperationFactory(
                for: unweighted.originChain,
                chainAccount: chainAccount
            )

            let feeWrapper = operationFactory.estimateFeeOperation({ builder in
                let collector = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                return try collector.addingToExtrinsic(builder: builder)
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

    func estimateCrossChainFee(
        request: XcmUnweightedTransferRequest,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    ) {
        let wrapper = crosschainFeeCalculator.crossChainFeeWrapper(
            request: request
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: completionClosure
        )
    }

    func submit(
        request: XcmTransferRequest,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    ) {
        do {
            let callBuilderWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: request.unweighted
            )

            guard let chainAccount = wallet.fetch(for: request.unweighted.originChain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let operationFactory = try createExtrinsicOperationFactory(
                for: request.unweighted.originChain,
                chainAccount: chainAccount
            )

            let submitWrapper = operationFactory.submit({ builder in
                let collector = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                return try collector.addingToExtrinsic(builder: builder)
            }, signer: signer, payingIn: request.originFeeAsset)

            submitWrapper.addDependency(wrapper: callBuilderWrapper)

            submitWrapper.targetOperation.completionBlock = {
                do {
                    let submittedModel = try submitWrapper.targetOperation.extractNoCancellableResultData()
                    let collector = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                    let extrinsicResult = XcmSubmitExtrinsic(
                        submittedModel: submittedModel,
                        callPath: collector.callPath
                    )

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
