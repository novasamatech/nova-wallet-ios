import Foundation
import BigInt
import NovaCrypto
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
        chainAsset: ChainAsset
    ) -> TransactionHistoryItem? {
        switch self {
        case let .local(item):
            return item
        case let .remote(item):
            return item.createTransaction(chainAsset: chainAsset)
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
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    func merge(
        remoteItems: [WalletRemoteHistoryItemProtocol],
        localItems: [TransactionHistoryItem]
    ) -> TransactionHistoryMergeResult {
        let existingIds = Set(remoteItems.map(\.localIdentifier))
        let existingRemoteIds = Set(remoteItems.map(\.remoteIdentifier))

        let minRemoteItem = remoteItems.last

        let identifiersToRemove: [String] = localItems.compactMap { item in
            if existingIds.contains(item.identifier) {
                return item.identifier
            }

            // if item is not local and not present remotely then remove it
            if !item.isIdentifierMatchesLocal, !existingRemoteIds.contains(item.identifier) {
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
                item.buildTransactionData(chainAsset: chainAsset)
            }

        let results = TransactionHistoryMergeResult(
            historyItems: transactionsItems,
            identifiersToRemove: identifiersToRemove
        )

        return results
    }
}

final class HydrationSwapCommissionNetter {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    func netCommission(in items: [TransactionHistoryItem]) throws -> [TransactionHistoryItem] {
        guard chainAsset.chain.hasSwapHydra else {
            return items
        }

        let beneficiary = try AssetExchangeCommissionConstants.hydrationBeneficiaryAddress.toAccountId()

        let commissions = commissionsByTxHash(in: items, beneficiary: beneficiary)

        guard !commissions.isEmpty else {
            return items
        }

        return items.map { item in
            guard
                let swap = item.swap,
                swap.assetIdOut == chainAsset.asset.assetId,
                let commission = commissions[item.txHash],
                let amountOut = Balance(swap.amountOut) else {
                return item
            }

            return item.replacingSwapAmountOut(amountOut.subtractOrZero(commission), in: swap)
        }
    }
}

private extension HydrationSwapCommissionNetter {
    func commissionsByTxHash(
        in items: [TransactionHistoryItem],
        beneficiary: AccountId
    ) -> [String: Balance] {
        items.reduce(into: [:]) { accum, item in
            guard
                item.callPath.isTransfer,
                item.status == .success,
                let receiver = item.receiver,
                let receiverId = try? receiver.toAccountId(using: chainAsset.chain.chainFormat),
                receiverId == beneficiary,
                let amountInPlank = item.amountInPlank,
                let amount = Balance(amountInPlank) else {
                return
            }

            accum[item.txHash, default: 0] += amount
        }
    }
}

private extension TransactionHistoryItem {
    func replacingSwapAmountOut(_ amountOut: Balance, in swap: SwapHistoryData) -> TransactionHistoryItem {
        TransactionHistoryItem(
            identifier: identifier,
            source: source,
            chainId: chainId,
            assetId: assetId,
            sender: sender,
            receiver: receiver,
            amountInPlank: amountInPlank,
            status: status,
            txHash: txHash,
            timestamp: timestamp,
            fee: fee,
            feeAssetId: feeAssetId,
            blockNumber: blockNumber,
            txIndex: txIndex,
            callPath: callPath,
            call: call,
            swap: SwapHistoryData(
                amountIn: swap.amountIn,
                assetIdIn: swap.assetIdIn,
                amountOut: String(amountOut),
                assetIdOut: swap.assetIdOut
            )
        )
    }
}
