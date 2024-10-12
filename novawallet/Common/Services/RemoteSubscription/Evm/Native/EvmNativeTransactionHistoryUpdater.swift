import Foundation
import Web3Core
import Operation_iOS
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
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let logger: LoggerProtocol

    init(
        chainAssetId: ChainAssetId,
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        operationFactory: EthereumOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        accountId: AccountId,
        logger: LoggerProtocol
    ) {
        self.chainAssetId = chainAssetId
        self.repository = repository
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountId = accountId
        self.logger = logger
    }

    private func createTransactionSaveOperation(
        _ transaction: EthereumBlockObject.Transaction,
        receiptOperation: BaseOperation<EthereumTransactionReceipt?>,
        blockNumber: BigUInt,
        timestamp: Int64,
        chainAssetId: ChainAssetId
    ) -> BaseOperation<Void> {
        repository.saveOperation({ [weak self] in
            let txHash = transaction.hash.toHex(includePrefix: true)
            let receipt = try receiptOperation.extractNoCancellableResultData()

            self?.logger.debug("Tx receipt \(transaction.hash): \(String(describing: receipt))")

            let fee = receipt?.fee.map { String($0) }

            let amount = transaction.isNativeTransfer ? String(transaction.amount) : nil

            let sender = try? transaction.sender.toAddress(using: .ethereum)
            let receiver = try? transaction.recepient?.toAddress(using: .ethereum)

            let source: TransactionHistoryItemSource = .evmNative
            let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

            let historyItem = TransactionHistoryItem(
                identifier: identifier,
                source: source,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: sender ?? "",
                receiver: receiver,
                amountInPlank: amount,
                status: receipt?.localStatus ?? .pending,
                txHash: txHash,
                timestamp: timestamp,
                fee: fee,
                feeAssetId: nil,
                blockNumber: UInt64(blockNumber),
                txIndex: nil,
                callPath: transaction.isNativeTransfer ? .evmNativeTransfer : .evmNativeTransaction,
                call: nil,
                swap: nil
            )

            return [historyItem]
        }, {
            []
        })
    }

    private func processTransactions(
        transactions: [EthereumBlockObject.Transaction],
        blockNumber: BigUInt,
        timestamp: Int64,
        chainAssetId: ChainAssetId
    ) {
        let wrappers = transactions.reduce([CompoundOperationWrapper<Void>]()) { accum, transaction in
            let txHash = transaction.hash.toHex(includePrefix: true)
            let transactionReceiptOperation = operationFactory.createTransactionReceiptOperation(for: txHash)

            let saveOperation = createTransactionSaveOperation(
                transaction,
                receiptOperation: transactionReceiptOperation,
                blockNumber: blockNumber,
                timestamp: timestamp,
                chainAssetId: chainAssetId
            )

            saveOperation.addDependency(transactionReceiptOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: saveOperation,
                dependencies: [transactionReceiptOperation]
            )

            accum.last.map { wrapper.addDependency(wrapper: $0) }

            return accum + [wrapper]
        }

        let notifyOperation = ClosureOperation<Void> { [weak self] in
            let hasSuccessfulSave = wrappers.contains { wrapper in
                if case .success = wrapper.targetOperation.result {
                    return true
                } else {
                    return false
                }
            }

            if hasSuccessfulSave {
                self?.eventCenter.notify(with: WalletTransactionListUpdated())
            }
        }

        wrappers.forEach { notifyOperation.addDependency($0.targetOperation) }

        let allOperations = wrappers.flatMap(\.allOperations) + [notifyOperation]

        operationQueue.addOperations(allOperations, waitUntilFinished: false)
    }
}

extension EvmNativeTransactionHistoryUpdater: EvmNativeTransactionHistoryUpdaterProtocol {
    func processEvmNativeTransactions(from blockNumber: BigUInt) {
        let operation = operationFactory.createBlockOperation(for: blockNumber)

        operation.completionBlock = { [weak self] in
            do {
                let block = try operation.extractNoCancellableResultData()

                if let strongSelf = self {
                    let targetTransactions = block.transactions.filter { transaction in
                        transaction.sender == strongSelf.accountId || transaction.recepient == strongSelf.accountId
                    }

                    if !targetTransactions.isEmpty {
                        self?.processTransactions(
                            transactions: targetTransactions,
                            blockNumber: blockNumber,
                            timestamp: Int64(block.timestamp),
                            chainAssetId: strongSelf.chainAssetId
                        )
                    } else {
                        strongSelf.logger.debug("No target transactions found for block: \(String(blockNumber))")
                    }
                }
            } catch {
                self?.logger.error("Did receive block fetch error: \(error)")
            }
        }

        operationQueue.addOperation(operation)
    }
}
