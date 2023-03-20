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

            let historyItem = TransactionHistoryItem(
                source: .evmNative,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: sender ?? "",
                receiver: receiver,
                amountInPlank: amount,
                status: receipt?.localStatus ?? .pending,
                txHash: txHash,
                timestamp: Int64(Date().timeIntervalSince1970),
                fee: fee,
                blockNumber: UInt64(blockNumber),
                txIndex: nil,
                callPath: transaction.isNativeTransfer ? .evmNativeTransfer : .evmNativeTransaction,
                call: nil
            )

            return [historyItem]
        }, {
            []
        })
    }

    private func processTransactions(
        transactions: [EthereumBlockObject.Transaction],
        blockNumber: BigUInt,
        chainAssetId: ChainAssetId
    ) {
        let wrappers = transactions.reduce([CompoundOperationWrapper<Void>]()) { accum, transaction in
            let txHash = transaction.hash.toHex(includePrefix: true)
            let transactionReceiptOperation = operationFactory.createTransactionReceiptOperation(for: txHash)

            let saveOperation = createTransactionSaveOperation(
                transaction,
                receiptOperation: transactionReceiptOperation,
                blockNumber: blockNumber,
                chainAssetId: chainAssetId
            )

            transactionReceiptOperation.addDependency(saveOperation)

            saveOperation.completionBlock = { [weak self] in
                guard case .success = saveOperation.result else {
                    return
                }

                self?.eventCenter.notify(with: WalletTransactionListUpdated())
            }

            let wrapper = CompoundOperationWrapper(
                targetOperation: saveOperation,
                dependencies: [transactionReceiptOperation]
            )

            accum.last.map { wrapper.addDependency(wrapper: $0) }

            return accum + [wrapper]
        }

        let allOperations = wrappers.flatMap(\.allOperations)

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
