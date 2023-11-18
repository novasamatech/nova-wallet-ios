import Foundation
import BigInt
import RobinHood

protocol PersistExtrinsicFactoryProtocol {
    func createTransferSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails
    ) -> CompoundOperationWrapper<Void>

    func createExtrinsicSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails
    ) -> CompoundOperationWrapper<Void>

    func createSwapSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistSwapDetails
    ) -> CompoundOperationWrapper<Void>
}

final class PersistExtrinsicFactory: PersistExtrinsicFactoryProtocol {
    let repository: AnyDataProviderRepository<TransactionHistoryItem>

    init(repository: AnyDataProviderRepository<TransactionHistoryItem>) {
        self.repository = repository
    }

    func createTransferSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistTransferDetails
    ) -> CompoundOperationWrapper<Void> {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let feeString = details.fee.map { String($0) }

        let txHash = details.txHash.toHex(includePrefix: true)
        let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

        let transferItem = TransactionHistoryItem(
            identifier: identifier,
            source: source,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: details.receiver,
            amountInPlank: String(details.amount),
            status: .pending,
            txHash: txHash,
            timestamp: timestamp,
            fee: feeString,
            feeAssetId: nil,
            blockNumber: nil,
            txIndex: nil,
            callPath: details.callPath,
            call: nil,
            swap: nil
        )

        let operation = repository.saveOperation({ [transferItem] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createExtrinsicSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistExtrinsicDetails
    ) -> CompoundOperationWrapper<Void> {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let feeString = details.fee.map { String($0) }

        let txHash = details.txHash.toHex(includePrefix: true)
        let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

        let item = TransactionHistoryItem(
            identifier: identifier,
            source: source,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: nil,
            amountInPlank: nil,
            status: .pending,
            txHash: txHash,
            timestamp: timestamp,
            fee: feeString,
            feeAssetId: nil,
            blockNumber: nil,
            txIndex: nil,
            callPath: details.callPath,
            call: nil,
            swap: nil
        )

        let operation = repository.saveOperation({ [item] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createSwapSaveOperation(
        source: TransactionHistoryItemSource,
        chainAssetId: ChainAssetId,
        details: PersistSwapDetails
    ) -> CompoundOperationWrapper<Void> {
        let timestamp = Int64(Date().timeIntervalSince1970)
        let feeString = details.fee.map { String($0) }

        let txHash = details.txHash.toHex(includePrefix: true)
        let identifier = TransactionHistoryItem.createIdentifier(from: txHash, source: source)

        let swap = SwapHistoryData(
            amountIn: String(details.amountIn),
            assetIdIn: details.assetIdIn.assetId,
            amountOut: String(details.amountOut),
            assetIdOut: details.assetIdOut.assetId
        )

        let item = TransactionHistoryItem(
            identifier: identifier,
            source: source,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: details.sender,
            receiver: details.receive,
            amountInPlank: nil,
            status: .pending,
            txHash: txHash,
            timestamp: timestamp,
            fee: feeString,
            feeAssetId: details.feeAssetId,
            blockNumber: nil,
            txIndex: nil,
            callPath: details.callPath,
            call: nil,
            swap: swap
        )

        let operation = repository.saveOperation({ [item] }, { [] })

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
