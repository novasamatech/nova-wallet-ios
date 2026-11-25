import Foundation
import Operation_iOS

protocol TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        historyDraft: @escaping EvmHistoryDraftClosure
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission>
}

// MARK: - TransactionSubmitMonitorFactoryProtocol

extension EvmTrackedSubmissionFactory: TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        historyDraft: @escaping EvmHistoryDraftClosure
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        let trackWrapper = submitAndTrackWrapper(closure, price: price, signer: signer, historyDraft: historyDraft)
        let budget = EvmTransactionMonitorTiming(chain: chain).waitBudget

        let resultWrapper = OperationCombiningService<TransactionTrackingResult>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [chain, trackingFacade] in
            let transaction = try trackWrapper.targetOperation.extractNoCancellableResultData()
            let key = TransactionTrackingKey(chainId: chain.chainId, transactionHash: transaction.transactionHash)

            return trackingFacade.createResultWrapper(for: key, budget: budget)
        }

        resultWrapper.addDependency(wrapper: trackWrapper)

        let mapOperation = ClosureOperation<EvmTransactionMonitorSubmission> {
            let transactionHash = try trackWrapper.targetOperation.extractNoCancellableResultData().transactionHash

            switch try resultWrapper.targetOperation.extractNoCancellableResultData() {
            case let .resolved(.included(inclusion)):
                return EvmTransactionMonitorSubmission(
                    status: .success(.init(transactionHash: transactionHash, blockHash: inclusion.blockHash))
                )
            case .resolved(.includedFailed):
                return EvmTransactionMonitorSubmission(status: .failure(.init(transactionHash: transactionHash)))
            case .resolved(.dropped):
                throw EvmTransactionMonitorError.dropped(transactionHash: transactionHash)
            case .stillPending:
                throw EvmTransactionMonitorError.stillPending(transactionHash: transactionHash)
            }
        }

        mapOperation.addDependency(resultWrapper.targetOperation)

        return resultWrapper
            .insertingHead(operations: trackWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }
}
