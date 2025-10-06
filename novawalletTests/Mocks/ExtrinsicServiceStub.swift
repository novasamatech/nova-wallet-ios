import Foundation
@testable import novawallet

final class ExtrinsicServiceStub: ExtrinsicServiceProtocol {
    let feeResult: Result<ExtrinsicFeeProtocol, Error>
    let submittedModelResult: Result<ExtrinsicSubmittedModel, Error>

    init(feeResult: Result<ExtrinsicFeeProtocol, Error>,
         submittedModelResult: Result<ExtrinsicSubmittedModel, Error>) {
        self.feeResult = feeResult
        self.submittedModelResult = submittedModelResult
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        queue.async {
            completionClosure(self.feeResult)
        }
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let results = indexes.map { index in
            FeeIndexedExtrinsicResult.IndexedResult(index: index, result: self.feeResult)
        }

        let feeResult = FeeIndexedExtrinsicResult(builderClosure: closure, results: results)

        completionClosure(feeResult)
    }

    func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let result = FeeIndexedExtrinsicResult.IndexedResult(index: 0, result: self.feeResult)
        let feeResult = FeeIndexedExtrinsicResult(builderClosure: nil, results: [result])

        completionClosure(feeResult)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        payingIn chainAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        queue.async {
            completionClosure(self.submittedModelResult)
        }
    }

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        payingIn chainAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicBuiltClosure
    ) {
        let builtResult = submittedModelResult.map { model in
            ExtrinsicBuiltModel(extrinsic: model.txHash, sender: model.sender)
        }
        
        queue.async {
            completionClosure(builtResult)
        }
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        payingIn chainAssetId: ChainAssetId?,
        indexes: IndexSet,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let result = SubmitIndexedExtrinsicResult.IndexedResult(index: 0, result: submittedModelResult)
        let submissionResult = SubmitIndexedExtrinsicResult(builderClosure: nil, results: [result])

        completionClosure(submissionResult)
    }

    func submitWithTxSplitter(
        _ txSplitter: ExtrinsicSplitting,
        payingIn chainAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let result = SubmitIndexedExtrinsicResult.IndexedResult(index: 0, result: submittedModelResult)
        let submissionResult = SubmitIndexedExtrinsicResult(builderClosure: nil, results: [result])

        completionClosure(submissionResult)
    }

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        payingIn chainAssetId: ChainAssetId?,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        _ = subscriptionIdClosure(0)

        switch submittedModelResult {
        case let .success(value):
            let model = ExtrinsicSubscribedStatusModel(
                statusUpdate: ExtrinsicStatusUpdate(
                    extrinsicHash: value.txHash,
                    extrinsicStatus: .inBlock(value.txHash)
                ),
                sender: value.sender
            )
            notificationClosure(.success(model))
        case let .failure(error):
            notificationClosure(.failure(error))
        }

    }

    func cancelExtrinsicWatch(for identifier: UInt16) {}
}

extension ExtrinsicServiceStub {
    static func dummy() -> ExtrinsicServiceStub {
        let fee = ExtrinsicFee(amount: 10000000000, payer: nil, weight: .init(refTime: 10005000, proofSize: 0))

        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
        
        let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(
            for: KnowChainId.westend
        )
        
        let submittedModel = ExtrinsicSubmittedModel(
            txHash: txHash,
            sender: .current(chainAccount)
        )
        
        return ExtrinsicServiceStub(feeResult: .success(fee), submittedModelResult: .success(submittedModel))
    }
}
