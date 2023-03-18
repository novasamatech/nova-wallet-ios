import Foundation
import Core
import RobinHood
import BigInt
import SubstrateSdk

protocol EvmNativeTransactionHistoryUpdaterProtocol {
    func processEvmNativeTransactions(from blockNumber: BigUInt)
}

final class EvmNativeTransactionHistoryUpdater {
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let operationFactory: EthereumOperationFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let accountId: AccountId
    let logger: LoggerProtocol

    init(
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        operationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        accountId: AccountId,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountId = accountId
        self.logger = logger
    }

    private func processTransaction(_ transaction: EthereumBlockObject.Transaction) {
        
    }
}

extension EvmNativeTransactionHistoryUpdater: EvmNativeTransactionHistoryUpdaterProtocol {
    func processEvmNativeTransactions(from blockNumber: BigUInt) {
        let operation = operationFactory.createBlockOperation(for: blockNumber)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let block = try operation.extractNoCancellableResultData()

                    if let strongSelf = self {
                        block.transactions.forEach { transaction in
                            let isTarget = transaction.from.toEthereumAccountId() == self?.accountId ||
                            transaction.to?.toEthereumAccountId() == self?.accountId

                            if isTarget {
                                strongSelf.processTransaction(transaction)
                            }
                        }
                    }
                } catch {
                    self?.logger.error("Did receive block fetch error: \(error)")
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}
