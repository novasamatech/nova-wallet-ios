import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

struct EvmTransactionMonitorSubmission {
    let status: TransactionStatus

    var transactionHash: String {
        switch status {
        case let .success(successTransaction):
            successTransaction.transactionHash
        case let .failure(failedTransaction):
            failedTransaction.transactionHash
        }
    }
}

extension EvmTransactionMonitorSubmission {
    enum TransactionStatus {
        struct SuccessTransaction {
            let transactionHash: String
            let blockHash: String
        }

        struct FailedTransaction {
            let transactionHash: String
        }

        case success(SuccessTransaction)
        case failure(FailedTransaction)
    }
}

protocol TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission>
}

final class TransactionSubmitMonitorFactory {
    let submissionService: EvmTransactionServiceProtocol
    let evmOperationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue
    let processingQueue = DispatchQueue(label: "io.novawallet.evm.transaction.monitor.\(UUID().uuidString)")

    init(
        submissionService: EvmTransactionServiceProtocol,
        evmOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.submissionService = submissionService
        self.evmOperationFactory = evmOperationFactory
        self.operationQueue = operationQueue
    }

    convenience init(
        submissionService: EvmTransactionServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue,
        timeoutInterval: Int,
        logger _: LoggerProtocol
    ) {
        let evmOperationFactory = EvmWebSocketOperationFactory(
            connection: connection,
            timeout: timeoutInterval
        )

        self.init(
            submissionService: submissionService,
            evmOperationFactory: evmOperationFactory,
            operationQueue: operationQueue
        )
    }

    func handleUpdate(
        subscriptionStatus: EvmSubscriptionStatus,
        subscriptionId: UInt16?,
        completion: @escaping (Result<EvmTransactionMonitorSubmission, Error>) -> Void
    ) {
        let operation = evmOperationFactory.createTransactionReceiptOperation(
            for: subscriptionStatus.transactionHash
        )

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: processingQueue
        ) { receiptResult in
            switch receiptResult {
            case let .success(receipt):
                guard let receipt else { return }
                self.handleFetchedReceipt(
                    receipt,
                    subscriptionId: subscriptionId,
                    completion: completion
                )
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func handleFetchedReceipt(
        _ receipt: EthereumTransactionReceipt,
        subscriptionId: UInt16?,
        completion: @escaping (Result<EvmTransactionMonitorSubmission, Error>) -> Void
    ) {
        guard let subscriptionId else { return }

        var status: EvmTransactionMonitorSubmission.TransactionStatus?

        switch receipt.localStatus {
        case .pending:
            status = nil
        case .success:
            status = .success(
                EvmTransactionMonitorSubmission.TransactionStatus.SuccessTransaction(
                    transactionHash: receipt.transactionHash,
                    blockHash: receipt.blockHash
                )
            )
        case .failed:
            status = .failure(
                EvmTransactionMonitorSubmission.TransactionStatus.FailedTransaction(
                    transactionHash: receipt.transactionHash
                )
            )
        }

        guard let status else { return }

        submissionService.cancelTransactionWatch(for: subscriptionId)

        let result = EvmTransactionMonitorSubmission(status: status)

        completion(.success(result))
    }
}

// MARK: - TransactionSubmitMonitorFactoryProtocol

extension TransactionSubmitMonitorFactory: TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        var subscriptionId: UInt16?

        let submissionOperation = AsyncClosureOperation<EvmTransactionMonitorSubmission>(
            operationClosure: { completion in
                self.submissionService.submitAndWatch(
                    closure,
                    price: price,
                    signer: signer,
                    runningIn: self.processingQueue,
                    subscriptionIdClosure: { id in
                        subscriptionId = id
                        return true
                    },
                    notificationClosure: { result in
                        switch result {
                        case let .success(status):
                            self.handleUpdate(
                                subscriptionStatus: status,
                                subscriptionId: subscriptionId,
                                completion: completion
                            )
                        case let .failure(error):
                            completion(.failure(error))
                        }
                    }
                )
            },
            cancelationClosure: {
                self.processingQueue.async {
                    guard let subscriptionId else { return }
                    self.submissionService.cancelTransactionWatch(for: subscriptionId)
                }
            }
        )

        return CompoundOperationWrapper(targetOperation: submissionOperation)
    }
}
