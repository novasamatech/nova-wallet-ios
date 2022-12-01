import Foundation
import BigInt
import RobinHood

protocol PersistExtrinsicFactoryProtocol {
    func createTransferSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails
    ) -> CompoundOperationWrapper<Void>

    func createExecutedTransferSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        blockNumber: UInt64,
        timestamp: Int64,
        status: TransactionHistoryItem.Status
    ) -> CompoundOperationWrapper<Void>

    func createExtrinsicSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails
    ) -> CompoundOperationWrapper<Void>

    func createExtrinsicDropOperation(for txHash: Data) -> CompoundOperationWrapper<Void>
}

final class PersistExtrinsicFactory: PersistExtrinsicFactoryProtocol {
    let repository: AnyDataProviderRepository<TransactionHistoryItem>

    init(repository: AnyDataProviderRepository<TransactionHistoryItem>) {
        self.repository = repository
    }

    func createTransferSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails
    ) -> CompoundOperationWrapper<Void> {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let feeString = details.fee.map { String($0) }

        let transferItem = TransactionHistoryItem(
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: details.receiver,
            amountInPlank: String(details.amount),
            status: .pending,
            txHash: details.txHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: feeString,
            blockNumber: nil,
            txIndex: nil,
            callPath: details.callPath,
            call: nil
        )

        let operation = repository.saveOperation({ [transferItem] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createExecutedTransferSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails,
        blockNumber: UInt64,
        timestamp: Int64,
        status: TransactionHistoryItem.Status
    ) -> CompoundOperationWrapper<Void> {
        let feeString = details.fee.map { String($0) }

        let transferItem = TransactionHistoryItem(
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: details.receiver,
            amountInPlank: String(details.amount),
            status: status,
            txHash: details.txHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: feeString,
            blockNumber: blockNumber,
            txIndex: nil,
            callPath: details.callPath,
            call: nil
        )

        let operation = repository.saveOperation({ [transferItem] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createExtrinsicSaveOperation(
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails
    ) -> CompoundOperationWrapper<Void> {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let feeString = details.fee.map { String($0) }

        let item = TransactionHistoryItem(
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: nil,
            amountInPlank: nil,
            status: .pending,
            txHash: details.txHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: feeString,
            blockNumber: nil,
            txIndex: nil,
            callPath: details.callPath,
            call: nil
        )

        let operation = repository.saveOperation({ [item] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createExtrinsicDropOperation(for txHash: Data) -> CompoundOperationWrapper<Void> {
        let txHashHex = txHash.toHex(includePrefix: true)
        let operation = repository.saveOperation({ [] }, { [txHashHex] })

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
