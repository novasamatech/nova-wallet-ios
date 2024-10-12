import Foundation
import Web3Core
import Operation_iOS
import BigInt

protocol ContractTransactionHistoryUpdaterProtocol {
    func processERC20Transfer(event: EventLog)
}

final class ContractTransactionHistoryUpdater {
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let accountId: AccountId
    let assetContracts: Set<EvmAssetContractId>
    let logger: LoggerProtocol

    private lazy var parser = EvmEventParser()

    init(
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        accountId: AccountId,
        assetContracts: Set<EvmAssetContractId>,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.accountId = accountId
        self.assetContracts = assetContracts
        self.logger = logger
    }

    private func createTransactionReceiptWrapper(
        for chainId: ChainModel.Id,
        transactionHash: String
    ) -> CompoundOperationWrapper<EthereumTransactionReceipt?> {
        guard let connection = chainRegistry.getOneShotConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let fetchOperation = operationFactory.createTransactionReceiptOperation(for: transactionHash)

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }

    private func createAndSaveTransaction(
        for event: EventLog,
        assetContract: EvmAssetContractId,
        transferEvent: ERC20TransferEvent,
        logger: LoggerProtocol
    ) {
        let transactionHashString = event.transactionHash.toHex(includePrefix: true)

        let transactionReceiptWrapper = createTransactionReceiptWrapper(
            for: assetContract.chainAssetId.chainId,
            transactionHash: transactionHashString
        )

        let saveOperation = repository.saveOperation({
            let receipt = try? transactionReceiptWrapper.targetOperation.extractNoCancellableResultData()

            logger.debug("Tx receipt \(transactionHashString): \(String(describing: receipt))")

            let fee = receipt?.fee.map { String($0) }

            let source: TransactionHistoryItemSource = .evmAsset

            let historyItem = TransactionHistoryItem(
                identifier: TransactionHistoryItem.createIdentifier(from: transactionHashString, source: source),
                source: source,
                chainId: assetContract.chainAssetId.chainId,
                assetId: assetContract.chainAssetId.assetId,
                sender: transferEvent.sender,
                receiver: transferEvent.receiver,
                amountInPlank: String(transferEvent.amount),
                status: .success,
                txHash: transactionHashString,
                timestamp: Int64(Date().timeIntervalSince1970),
                fee: fee,
                feeAssetId: nil,
                blockNumber: UInt64(event.blockNumber),
                txIndex: nil,
                callPath: CallCodingPath.erc20Tranfer,
                call: nil,
                swap: nil
            )

            return [historyItem]
        }, {
            []
        })

        saveOperation.addDependency(transactionReceiptWrapper.targetOperation)

        saveOperation.completionBlock = { [weak self] in
            guard case .success = saveOperation.result else {
                return
            }

            self?.eventCenter.notify(with: WalletTransactionListUpdated())
        }

        let operations = transactionReceiptWrapper.allOperations + [saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func insertOrUpdateTransaction(for event: EventLog) {
        let contract = event.address.addressData

        let optAssetContract = assetContracts.first { assetContract in
            let assetContractData = try? assetContract.contract.toEthereumAccountId()
            return contract == assetContractData
        }

        guard let assetContract = optAssetContract else {
            logger.error("Can't find evm asset for contract \(event.address)")
            return
        }

        guard let transferEvent = parser.parseERC20Transfer(from: event) else {
            logger.error("Can't parse ERC20 transfer event: \(event)")
            return
        }

        logger.debug("Saving new ERC20 transaction \(event.transactionHash.toHex(includePrefix: true))")

        createAndSaveTransaction(
            for: event,
            assetContract: assetContract,
            transferEvent: transferEvent,
            logger: logger
        )
    }

    private func removeTransaction(for event: EventLog) {
        logger.debug("Removing ERC20 transaction \(event.transactionHash.toHex(includePrefix: true))")

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

extension ContractTransactionHistoryUpdater: ContractTransactionHistoryUpdaterProtocol {
    func processERC20Transfer(event: EventLog) {
        if !event.removed {
            insertOrUpdateTransaction(for: event)
        } else {
            removeTransaction(for: event)
        }
    }
}
