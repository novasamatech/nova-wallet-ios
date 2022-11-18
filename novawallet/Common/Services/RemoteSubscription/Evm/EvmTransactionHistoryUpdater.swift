import Foundation
import Core
import RobinHood
import BigInt

protocol EvmTransactionHistoryUpdaterProtocol {
    func processERC20Transfer(event: EventLog)
}

final class EvmTransactionHistoryUpdater {
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let accountId: AccountId
    let assetContracts: Set<EvmAssetContractId>

    private lazy var parser = EvmEventParser()

    init(
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountId = accountId
        self.assetContracts = assetContracts
    }

    private func insertOrUpdateTransaction(for event: EventLog) {
        let contract = event.address.addressData

        let optAssetContract = assetContracts.first { assetContract in
            let assetContractData = try? assetContract.contract.toEthereumAccountId()
            return contract == assetContractData
        }

        guard let assetContract = optAssetContract else {
            return
        }

        guard let transferEvent = parser.parseERC20Transfer(from: event) else {
            return
        }

        let callPath = CallCodingPath(
            moduleName: contract.toHex(includePrefix: true),
            callName: EvmSubscriptionMessageFactory.erc20Transfer
        )

        let historyItem = TransactionHistoryItem(
            chainId: assetContract.chainAssetId.chainId,
            assetId: assetContract.chainAssetId.assetId,
            sender: transferEvent.sender.toHex(),
            receiver: transferEvent.receiver.toHex(),
            amountInPlank: String(transferEvent.amount),
            status: .success,
            txHash: event.transactionHash.toHex(),
            timestamp: Int64(Date().timeIntervalSince1970),
            fee: nil,
            blockNumber: UInt64(event.blockNumber),
            txIndex: nil,
            callPath: callPath,
            call: nil
        )

        let saveOperation = repository.saveOperation({
            [historyItem]
        }, {
            []
        })

        saveOperation.completionBlock = { [weak self] in
            guard case .success = saveOperation.result else {
                return
            }

            self?.eventCenter.notify(with: WalletTransactionListUpdated())
        }

        operationQueue.addOperation(saveOperation)
    }

    private func removeTransaction(for event: EventLog) {
        let saveOperation = repository.saveOperation({
            []
        }, {
            [event.transactionHash.toHex()]
        })

        saveOperation.completionBlock = { [weak self] in
            guard case .success = saveOperation.result else {
                return
            }

            self?.eventCenter.notify(with: WalletTransactionListUpdated())
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension EvmTransactionHistoryUpdater: EvmTransactionHistoryUpdaterProtocol {
    func processERC20Transfer(event: EventLog) {
        if !event.removed {
            insertOrUpdateTransaction(for: event)
        } else {
            removeTransaction(for: event)
        }
    }
}
