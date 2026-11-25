import Foundation
import Operation_iOS

typealias EvmHistoryDraftClosure = (EvmSubmittedTransaction) throws -> TransactionHistoryItem?

protocol EvmTrackedSubmissionFactoryProtocol {
    func submitAndTrackWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        historyDraft: @escaping EvmHistoryDraftClosure
    ) -> CompoundOperationWrapper<EvmSubmittedTransaction>
}

final class EvmTrackedSubmissionFactory {
    let chain: ChainModel
    let submissionService: EvmTransactionServiceProtocol
    let trackingFacade: TransactionTrackingFacadeProtocol
    let historyRepository: AnyDataProviderRepository<TransactionHistoryItem>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        submissionService: EvmTransactionServiceProtocol,
        trackingFacade: TransactionTrackingFacadeProtocol,
        historyRepository: AnyDataProviderRepository<TransactionHistoryItem>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
        self.submissionService = submissionService
        self.trackingFacade = trackingFacade
        self.historyRepository = historyRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - EvmTrackedSubmissionFactoryProtocol

extension EvmTrackedSubmissionFactory: EvmTrackedSubmissionFactoryProtocol {
    func submitAndTrackWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        historyDraft: @escaping EvmHistoryDraftClosure
    ) -> CompoundOperationWrapper<EvmSubmittedTransaction> {
        // Built on execution: the builder closure may read operations the caller makes this wrapper depend on.
        let submissionWrapper = OperationCombiningService<EvmSubmittedTransaction>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [submissionService] in
            submissionService.createSubmissionWrapper(closure, price: price, signer: signer)
        }

        let draftOperation = historyRepository.saveOperation({
            let transaction = try submissionWrapper.targetOperation.extractNoCancellableResultData()

            return try historyDraft(transaction).map { [$0] } ?? []
        }, {
            []
        })

        draftOperation.addDependency(submissionWrapper.targetOperation)

        let trackOperation = ClosureOperation<EvmSubmittedTransaction> { [chain, trackingFacade, logger] in
            let transaction = try submissionWrapper.targetOperation.extractNoCancellableResultData()

            if case let .failure(error) = draftOperation.result {
                logger.warning("Tracking: \(transaction.transactionHash) draft not saved \(error)")
            }

            trackingFacade.track(
                TransactionTrackingRequest(
                    key: TransactionTrackingKey(chainId: chain.chainId, transactionHash: transaction.transactionHash),
                    evidence: .evm(EvmTrackingEvidence(sender: transaction.sender, nonce: transaction.nonce)),
                    mode: .fresh
                )
            )

            return transaction
        }

        trackOperation.addDependency(draftOperation)

        return submissionWrapper
            .insertingTail(operation: draftOperation)
            .insertingTail(operation: trackOperation)
    }
}
