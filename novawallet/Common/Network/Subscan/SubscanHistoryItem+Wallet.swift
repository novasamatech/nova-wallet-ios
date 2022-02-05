import Foundation
import CommonWallet
import IrohaCrypto

extension SubscanRewardItemData: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String { "\(recordId)-\(eventIndex)" }
    var localIdentifier: String { "\(recordId)-\(eventIndex)" }
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .rewards }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            assetId: assetId,
            chainAssetInfo: chainAssetInfo
        )
    }
}

extension SubscanTransferItemData: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String { hash }
    var localIdentifier: String { hash }
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex.value }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .transfers }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            assetId: assetId,
            chainAssetInfo: chainAssetInfo
        )
    }
}

extension SubscanConcreteExtrinsicsItemData: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String { hash }
    var localIdentifier: String { hash }
    var itemBlockNumber: UInt64 { blockNumber }
    var itemExtrinsicIndex: UInt16 { extrinsicIndex.value }
    var itemTimestamp: Int64 { timestamp }
    var label: WalletRemoteHistorySourceLabel { .extrinsics }

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            assetId: assetId,
            chainAssetInfo: chainAssetInfo
        )
    }
}
