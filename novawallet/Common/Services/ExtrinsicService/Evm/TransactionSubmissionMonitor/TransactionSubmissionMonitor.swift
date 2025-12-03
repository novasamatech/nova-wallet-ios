import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

struct EvmTransactionMonitorSubmission {
    let status: TransactionStatus
    
    var transactionHash: String {
        switch status {
        case let .success(successTransaction):
            successTransaction.transcationHash
        case let .failure(failedTransaction):
            failedTransaction.transcationHash
        }
    }
}

extension EvmTransactionMonitorSubmission {
    enum TransactionStatus {
        struct SuccessTransaction {
            let transcationHash: String
            let blockHash: String
        }

        struct FailedTransaction {
            let transcationHash: String
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
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission?>
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
        logger: LoggerProtocol
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
}

// MARK: - TransactionSubmitMonitorFactoryProtocol

extension TransactionSubmitMonitorFactory: TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission?> {
        var subscriptionId: UInt16?
        
        let submissionOperation = AsyncClosureOperation<EvmSubscriptionStatus>(
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
                            completion(.success(status))
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
        
        let receiptWrapper: CompoundOperationWrapper<EthereumTransactionReceipt?>
        receiptWrapper = OperationCombiningService.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let status = try submissionOperation.extractNoCancellableResultData()
            let operation = self.evmOperationFactory.createTransactionReceiptOperation(
                for: status.transactionHash
            )
            return CompoundOperationWrapper(targetOperation: operation)
        }
        
        let statusOperation = ClosureOperation<EvmTransactionMonitorSubmission.TransactionStatus?> {
            let receipt = try receiptWrapper.targetOperation.extractNoCancellableResultData()
            
            guard
                let receipt,
                let subscriptionId
            else { return nil }
            
            switch receipt.localStatus {
            case .pending:
                return nil
            case .success:
                self.submissionService.cancelTransactionWatch(for: subscriptionId)
                return .success(
                    EvmTransactionMonitorSubmission.TransactionStatus.SuccessTransaction(
                        transcationHash: receipt.transactionHash,
                        blockHash: receipt.blockHash
                    )
                )
            case .failed:
                self.submissionService.cancelTransactionWatch(for: subscriptionId)
                return .failure(
                    EvmTransactionMonitorSubmission.TransactionStatus.FailedTransaction(
                        transcationHash: receipt.transactionHash
                    )
                )
            }
        }
        
        let mappingOperation = ClosureOperation<EvmTransactionMonitorSubmission?> {
            let receipt = try receiptWrapper.targetOperation.extractNoCancellableResultData()
            let status = try statusOperation.extractNoCancellableResultData()
            
            guard let status, let receipt else { return nil }
            
            return EvmTransactionMonitorSubmission(status: status)
        }
        
        receiptWrapper.addDependency(operations: [submissionOperation])
        statusOperation.addDependency(receiptWrapper.targetOperation)
        mappingOperation.addDependency(statusOperation)
        
        let dependencies = [submissionOperation]
            + receiptWrapper.allOperations
            + [statusOperation]
        
        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
