import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk

struct TransactionHistoryMergeResult {
    let historyItems: [TransactionHistoryItem]
    let identifiersToRemove: [String]
}

enum TransactionHistoryMergeItem {
    case local(item: TransactionHistoryItem)
    case remote(remote: WalletRemoteHistoryItemProtocol)

    func compareWithItem(_ item: TransactionHistoryMergeItem) -> Bool {
        switch (self, item) {
        case let (.local(localItem1), .local(localItem2)):
            if localItem1.status == .pending, localItem2.status != .pending {
                return true
            } else {
                return compareBlockNumberIfExists(
                    number1: localItem1.blockNumber,
                    number2: localItem2.blockNumber,
                    timestamp1: localItem1.timestamp,
                    timestamp2: localItem2.timestamp
                )
            }

        case let (.local(localItem), .remote(remoteItem)):
            if localItem.status == .pending {
                return true
            } else {
                return compareBlockNumberIfExists(
                    number1: localItem.blockNumber,
                    number2: remoteItem.itemBlockNumber,
                    timestamp1: localItem.timestamp,
                    timestamp2: remoteItem.itemTimestamp
                )
            }
        case let (.remote(remoteItem), .local(localItem)):
            if localItem.status == .pending {
                return false
            } else {
                return compareBlockNumberIfExists(
                    number1: remoteItem.itemBlockNumber,
                    number2: localItem.blockNumber,
                    timestamp1: remoteItem.itemTimestamp,
                    timestamp2: localItem.timestamp
                )
            }
        case let (.remote(remoteItem1), .remote(remoteItem2)):
            return compareBlockNumberIfExists(
                number1: remoteItem1.itemBlockNumber,
                number2: remoteItem2.itemBlockNumber,
                timestamp1: remoteItem1.itemTimestamp,
                timestamp2: remoteItem2.itemTimestamp
            )
        }
    }

    func buildTransactionData(
        address _: String,
        chainAsset: ChainAsset,
        utilityAsset _: AssetModel
    ) -> TransactionHistoryItem? {
        switch self {
        case let .local(item):
            return item
        case let .remote(item):
            if let etherscanItem = item as? EtherscanHistoryElement {
                return etherscanItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
            } else if let subqueryItem = item as? SubqueryHistoryElement {
                return subqueryItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
            } else {
                return nil
            }
        }
    }

    private func compareBlockNumberIfExists(
        number1: UInt64?,
        number2: UInt64?,
        timestamp1: Int64,
        timestamp2: Int64
    ) -> Bool {
        if let number1 = number1, let number2 = number2 {
            return number1 != number2 ? number1 > number2 : timestamp1 > timestamp2
        }

        return timestamp1 > timestamp2
    }
}

final class TransactionHistoryMergeManager {
    let address: String
    let chainAsset: ChainAsset
    let utilityAsset: AssetModel

    init(
        address: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) {
        self.address = address
        self.chainAsset = chainAsset
        self.utilityAsset = utilityAsset
    }

    func merge(
        remoteItems: [WalletRemoteHistoryItemProtocol],
        localItems: [TransactionHistoryItem]
    ) -> TransactionHistoryMergeResult {
        let existingHashes = Set(remoteItems.map(\.localIdentifier))
        let minRemoteItem = remoteItems.last

        let identifiersToRemove: [String] = localItems.compactMap { item in
            if existingHashes.contains(item.identifier) {
                return item.identifier
            }

            guard let remoteItem = minRemoteItem else {
                return nil
            }

            if item.timestamp < remoteItem.itemTimestamp {
                return item.identifier
            }

            return nil
        }

        let filterSet = Set(identifiersToRemove)
        let localMergeItems: [TransactionHistoryMergeItem] = localItems.compactMap { item in
            guard !filterSet.contains(item.identifier) else {
                return nil
            }

            return TransactionHistoryMergeItem.local(item: item)
        }

        let remoteMergeItems: [TransactionHistoryMergeItem] = remoteItems.map {
            TransactionHistoryMergeItem.remote(remote: $0)
        }

        let transactionsItems = (localMergeItems + remoteMergeItems)
            .sorted { $0.compareWithItem($1) }
            .compactMap { item in
                item.buildTransactionData(
                    address: address,
                    chainAsset: chainAsset,
                    utilityAsset: utilityAsset
                )
            }

        let results = TransactionHistoryMergeResult(
            historyItems: transactionsItems,
            identifiersToRemove: identifiersToRemove
        )

        return results
    }
}

import BigInt

extension EtherscanHistoryElement {
    func createTransactionItem(chainAssetId: ChainAssetId) -> TransactionHistoryItem {
        let gasValue = BigUInt(gasUsed) ?? 0
        let gasPriceValue = BigUInt(gasPrice) ?? 0
        let feeInPlank = gasValue * gasPriceValue

        return .init(
            source: .evm,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: from,
            receiver: to,
            amountInPlank: value,
            status: .success,
            txHash: hash,
            timestamp: itemTimestamp,
            fee: String(feeInPlank),
            blockNumber: nil,
            txIndex: nil,
            callPath: CallCodingPath.erc20Tranfer,
            call: nil
        )
    }
}

extension SubqueryHistoryElement {
    func createTransactionItem(chainAssetId: ChainAssetId) -> TransactionHistoryItem? {
        if let transfer = self.transfer {
            return .init(
                source: .substrate,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: transfer.sender,
                receiver: transfer.receiver,
                amountInPlank: transfer.amount,
                status: transfer.success ? .success : .failed,
                txHash: identifier,
                timestamp: itemTimestamp,
                fee: transfer.amount,
                blockNumber: blockNumber,
                txIndex: nil,
                callPath: CallCodingPath.transfer,
                call: nil
            )
        } else if let assetTransfer = assetTransfer {
            return .init(
                source: .substrate,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: assetTransfer.sender,
                receiver: assetTransfer.receiver,
                amountInPlank: assetTransfer.amount,
                status: assetTransfer.success ? .success : .failed,
                txHash: identifier,
                timestamp: itemTimestamp,
                fee: assetTransfer.fee,
                blockNumber: blockNumber,
                txIndex: nil,
                callPath: CallCodingPath.assetsTransfer(for: nil),
                call: nil
            )
        } else if let extrinsic = extrinsic {
            return .init(
                source: .substrate,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: "",
                receiver: nil,
                amountInPlank: nil,
                status: extrinsic.success ? .success : .failed,
                txHash: identifier,
                timestamp: itemTimestamp,
                fee: extrinsic.fee,
                blockNumber: blockNumber,
                txIndex: nil,
                callPath: CallCodingPath(moduleName: extrinsic.module, callName: extrinsic.call),
                // TODO:
                call: nil
            )
        } else if let reward = reward {
            return .init(
                source: .substrate,
                chainId: chainAssetId.chainId,
                assetId: chainAssetId.assetId,
                sender: reward.validator ?? "",
                receiver: nil,
                amountInPlank: reward.amount,
                status: .success,
                txHash: identifier,
                timestamp: itemTimestamp,
                fee: nil,
                blockNumber: blockNumber,
                txIndex: nil,
                callPath: reward.isReward ? .reward : .slash,
                call: nil
            )
        } else {
            return nil
        }
    }
}
