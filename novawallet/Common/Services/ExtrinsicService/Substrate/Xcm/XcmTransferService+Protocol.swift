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

            let callBuilderWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: unweighted,
                transfers: xcmTransfers,
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
        xcmTransfers: XcmTransfers,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmTransferCrosschainFeeClosure
    ) {
        let wrapper = crosschainFeeCalculator.crossChainFeeWrapper(
            request: request,
            xcmTransfers: xcmTransfers
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
        xcmTransfers: XcmTransfers,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping XcmExtrinsicSubmitClosure
    ) {
        do {
            let callBuilderWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: request.unweighted,
                transfers: xcmTransfers,
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
                let collector = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                return try collector.addingToExtrinsic(builder: builder)
            }, signer: signer, payingIn: request.originFeeAsset)

            submitWrapper.addDependency(wrapper: callBuilderWrapper)

            submitWrapper.targetOperation.completionBlock = {
                do {
                    let txHash = try submitWrapper.targetOperation.extractNoCancellableResultData()
                    let collector = try callBuilderWrapper.targetOperation.extractNoCancellableResultData()
                    let extrinsicResult = XcmSubmitExtrinsic(txHash: txHash, callPath: collector.callPath)

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
