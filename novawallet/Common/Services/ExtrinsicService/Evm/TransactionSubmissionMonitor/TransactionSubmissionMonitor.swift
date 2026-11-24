import Foundation
import Operation_iOS
import SubstrateSdk

protocol TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission>
}

final class TransactionSubmitMonitorFactory {
    let submissionService: EvmTransactionServiceProtocol
    let queryOperationFactory: EthereumOperationFactoryProtocol
    let headsConnection: JSONRPCEngine?
    let timing: EvmTransactionMonitorTiming
    let operationQueue: OperationQueue
    let processingQueue = DispatchQueue(label: "io.novawallet.evm.transaction.monitor.\(UUID().uuidString)")
    let logger: LoggerProtocol

    init(
        submissionService: EvmTransactionServiceProtocol,
        queryOperationFactory: EthereumOperationFactoryProtocol,
        headsConnection: JSONRPCEngine?,
        timing: EvmTransactionMonitorTiming,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.submissionService = submissionService
        self.queryOperationFactory = queryOperationFactory
        self.headsConnection = headsConnection
        self.timing = timing
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - TransactionSubmitMonitorFactoryProtocol

extension TransactionSubmitMonitorFactory: TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        // Built on execution: the builder closure may read operations the caller makes this wrapper depend on.
        let submissionWrapper = OperationCombiningService<EvmSubmittedTransaction>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [submissionService] in
            submissionService.createSubmissionWrapper(closure, price: price, signer: signer)
        }

        let processingQueue = processingQueue

        let watcher = EvmTransactionWatcher(
            queryOperationFactory: queryOperationFactory,
            headsConnection: headsConnection,
            timing: timing,
            processingQueue: processingQueue,
            operationQueue: operationQueue,
            logger: logger
        )

        let monitorOperation = AsyncClosureOperation<EvmTransactionMonitorSubmission>(
            operationClosure: { completion in
                let transaction = try submissionWrapper.targetOperation.extractNoCancellableResultData()

                processingQueue.async {
                    watcher.start(watching: transaction, completion: completion)
                }
            },
            cancelationClosure: {
                processingQueue.async {
                    watcher.stop()
                }
            }
        )

        monitorOperation.addDependency(submissionWrapper.targetOperation)

        return submissionWrapper.insertingTail(operation: monitorOperation)
    }
}
