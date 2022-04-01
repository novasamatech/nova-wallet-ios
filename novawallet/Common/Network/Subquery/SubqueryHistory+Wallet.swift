import Foundation
import CommonWallet
import BigInt

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var remoteIdentifier: String {
        identifier
    }

    var localIdentifier: String { extrinsicHash ?? identifier }

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

    func createTransactionForAddress(
        _ address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        if let transfer = transfer {
            return createTransactionFromTransfer(
                transfer,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        } else if let reward = reward {
            return createTransactionFromReward(
                reward,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        } else if let extrinsic = extrinsic {
            return createTransactionFromExtrinsic(
                extrinsic,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        } else if let assetTransfer = assetTransfer {
            return createTransactionFromTransfer(
                assetTransfer,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        } else {
            // we shouldn't crash if broken data received
            return AssetTransactionData(
                transactionId: "",
                status: .commited,
                assetId: "",
                peerId: "",
                peerFirstName: nil,
                peerLastName: nil,
                peerName: nil,
                details: "",
                amount: AmountDecimal(value: 0),
                fees: [],
                timestamp: 0,
                type: "",
                reason: nil,
                context: nil
            )
        }
    }

    private func createTransactionFromTransfer(
        _ transfer: SubqueryTransfer,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = transfer.success ? .commited : .rejected

        let isSender = address.caseInsensitiveCompare(transfer.sender) == .orderedSame
        let peerAddress = isSender ? transfer.receiver : transfer.sender
        let accountId = try? peerAddress.toAccountId(using: chainAssetInfo.chain)
        let peerId = accountId?.toHex() ?? peerAddress

        let amountValue = BigUInt(transfer.amount) ?? 0
        let amountDecimal = Decimal.fromSubstrateAmount(
            amountValue,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? 0

        let feeValue = BigUInt(transfer.fee) ?? 0
        let feeDecimal = Decimal.fromSubstrateAmount(
            feeValue,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? 0

        let fee = AssetTransactionFee(
            identifier: assetId,
            assetId: assetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type: TransactionType = isSender ? .outgoing : .incoming

        return AssetTransactionData(
            transactionId: extrinsicHash ?? identifier,
            status: status,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionFromReward(
        _ reward: SubqueryRewardOrSlash,
        address _: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let amountValue = BigUInt(reward.amount) ?? 0
        let amountDecimal = Decimal.fromSubstrateAmount(
            amountValue,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? 0

        let type: TransactionType = reward.isReward ? .reward : .slash

        let context = HistoryRewardContext(
            validator: reward.validator,
            era: reward.era,
            eventId: identifier
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: .commited,
            assetId: assetId,
            peerId: extrinsicHash ?? "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [],
            timestamp: itemTimestamp,
            type: type.rawValue,
            reason: nil,
            context: context.toContext()
        )
    }

    private func createTransactionFromExtrinsic(
        _ extrinsic: SubqueryExtrinsic,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        let accountId = try? address.toAccountId(using: chainAssetInfo.chain)
        let peerId = accountId?.toHex() ?? address

        let amountValue = BigUInt(extrinsic.fee) ?? 0
        let amountDecimal = Decimal.fromSubstrateAmount(
            amountValue,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? 0

        return AssetTransactionData(
            transactionId: extrinsicHash ?? identifier,
            status: status,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: extrinsic.module,
            peerLastName: extrinsic.call,
            peerName: "\(extrinsic.module) \(extrinsic.call)",
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [],
            timestamp: itemTimestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }
}
