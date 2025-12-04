import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        timeout: EvmTransactionMonitorTimeout
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission>
}

extension TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        submitAndMonitorWrapper(
            closure,
            price: price,
            signer: signer,
            timeout: .default
        )
    }
}

final class TransactionSubmitMonitorFactory {
    let submissionService: EvmTransactionServiceProtocol
    let evmOperationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue
    let processingQueue = DispatchQueue(label: "io.novawallet.evm.transaction.monitor.\(UUID().uuidString)")
    let logger: LoggerProtocol

    init(
        submissionService: EvmTransactionServiceProtocol,
        evmOperationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.submissionService = submissionService
        self.evmOperationFactory = evmOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
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
            operationQueue: operationQueue,
            logger: logger
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

    func checkAndUpdateTimeoutState(
        maxBlocks: Int,
        _ startBlockNumber: inout BigUInt?,
        _ lastBlockNumber: BigUInt,
        _ blocksPassed: inout BigUInt
    ) -> Bool {
        if startBlockNumber == nil {
            startBlockNumber = lastBlockNumber
            logger.debug("EVM monitor: initial block \(lastBlockNumber)")
        } else if let startBlockNumber, lastBlockNumber > startBlockNumber {
            blocksPassed = lastBlockNumber - startBlockNumber

            logger.debug("EVM monitor: \(blocksPassed) blocks observed")
        }

        return blocksPassed < maxBlocks
    }

    func handleTimeout(
        for subscriptionId: UInt16?,
        blocksPassed: BigUInt,
        completion: @escaping (Result<EvmTransactionMonitorSubmission, Error>) -> Void
    ) {
        if let subscriptionId {
            submissionService.cancelTransactionWatch(for: subscriptionId)
        }

        logger.warning("EVM monitor: timeout after \(blocksPassed) blocks")
        completion(.failure(EvmTransactionMonitorError.timeout(blocksWaited: blocksPassed)))
    }
}

// MARK: - TransactionSubmitMonitorFactoryProtocol

extension TransactionSubmitMonitorFactory: TransactionSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        _ closure: @escaping EvmTransactionBuilderClosure,
        price: EvmTransactionPrice,
        signer: SigningWrapperProtocol,
        timeout: EvmTransactionMonitorTimeout
    ) -> CompoundOperationWrapper<EvmTransactionMonitorSubmission> {
        var subscriptionId: UInt16?
        var startBlockNumber: BigUInt?
        var blocksPassed: BigUInt = 0

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
                            let timeIsValid = self.checkAndUpdateTimeoutState(
                                maxBlocks: timeout.maxBlocks,
                                &startBlockNumber,
                                status.lastBlockNumber,
                                &blocksPassed
                            )

                            guard timeIsValid else {
                                self.handleTimeout(
                                    for: subscriptionId,
                                    blocksPassed: blocksPassed,
                                    completion: completion
                                )
                                return
                            }

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
