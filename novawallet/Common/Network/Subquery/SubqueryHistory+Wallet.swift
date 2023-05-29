import Foundation
import CommonWallet
import BigInt

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        identifier
    }

    var localIdentifier: String {
        let localId = extrinsicHash ?? identifier

        return TransactionHistoryItem.createIdentifier(from: localId, source: .substrate)
    }

    var itemBlockNumber: UInt64 {
        blockNumber
    }

    var itemExtrinsicIndex: UInt16 {
        extrinsicIdx ?? 0
    }

    var itemTimestamp: Int64 {
        Int64(timestamp) ?? 0
    }

    var label: WalletRemoteHistorySourceLabel {
        if transfer != nil {
            return .transfers
        } else if reward != nil {
            return .rewards
        } else {
            return .extrinsics
        }
    }

    func createTransaction(
        chainAsset: ChainAsset
    ) -> TransactionHistoryItem? {
        if let transfer = transfer {
            return createTransactionFromTransfer(
                transfer,
                chainAssetId: chainAsset.chainAssetId,
                chainFormat: chainAsset.chain.chainFormat
            )
        } else if let reward = reward {
            return createTransactionFromReward(
                reward,
                chainAssetId: chainAsset.chainAssetId,
                chainFormat: chainAsset.chain.chainFormat
            )
        } else if let extrinsic = extrinsic {
            return createTransactionFromExtrinsic(
                extrinsic,
                chainAssetId: chainAsset.chainAssetId,
                chainFormat: chainAsset.chain.chainFormat
            )
        } else if let assetTransfer = assetTransfer {
            return createTransactionFromTransfer(
                assetTransfer,
                chainAssetId: chainAsset.chainAssetId,
                chainFormat: chainAsset.chain.chainFormat
            )
        } else {
            return nil
        }
    }

    private func createTransactionFromTransfer(
        _ transfer: SubqueryTransfer,
        chainAssetId: ChainAssetId,
        chainFormat: ChainFormat
    ) -> TransactionHistoryItem {
        .init(
            source: .substrate,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: transfer.sender.normalize(for: chainFormat) ?? transfer.sender,
            receiver: transfer.receiver.normalize(for: chainFormat) ?? transfer.receiver,
            amountInPlank: transfer.amount,
            status: transfer.success ? .success : .failed,
            txHash: extrinsicHash ?? identifier,
            timestamp: itemTimestamp,
            fee: transfer.amount,
            blockNumber: blockNumber,
            txIndex: nil,
            callPath: CallCodingPath.transfer,
            call: nil
        )
    }

    private func createTransactionFromReward(
        _ reward: SubqueryRewardOrSlash,
        chainAssetId: ChainAssetId,
        chainFormat: ChainFormat
    ) -> TransactionHistoryItem {
        let context = HistoryRewardContext(
            validator: reward.validator,
            era: reward.era,
            eventId: identifier
        )
        return .init(
            source: .substrate,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: reward.validator?.normalize(for: chainFormat) ?? "",
            receiver: address.normalize(for: chainFormat) ?? address,
            amountInPlank: reward.amount,
            status: .success,
            txHash: extrinsicHash ?? identifier,
            timestamp: itemTimestamp,
            fee: nil,
            blockNumber: blockNumber,
            txIndex: nil,
            callPath: reward.isReward ? .reward : .slash,
            call: try? JSONEncoder().encode(context)
        )
    }

    private func createTransactionFromExtrinsic(
        _ extrinsic: SubqueryExtrinsic,
        chainAssetId: ChainAssetId,
        chainFormat: ChainFormat
    ) -> TransactionHistoryItem {
        .init(
            source: .substrate,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            sender: address.normalize(for: chainFormat) ?? address,
            receiver: nil,
            amountInPlank: nil,
            status: extrinsic.success ? .success : .failed,
            txHash: extrinsicHash ?? identifier,
            timestamp: itemTimestamp,
            fee: extrinsic.fee,
            blockNumber: blockNumber,
            txIndex: nil,
            callPath: CallCodingPath(moduleName: extrinsic.module, callName: extrinsic.call),
            call: extrinsic.call.data(using: .utf8)
        )
    }
}
