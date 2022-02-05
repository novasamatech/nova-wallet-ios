import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import SubstrateSdk

extension AssetTransactionData {
    static func createTransaction(
        from item: SubscanTransferItemData,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus

        if item.finalized == false {
            status = .pending
        } else if let state = item.success {
            status = state ? .commited : .rejected
        } else {
            status = .pending
        }

        let senderId = try? item.sender.toAccountId()
        let receiverId = try? address.toAccountId()
        let isSender = senderId == receiverId

        let peerAddress = isSender ? item.receiver : item.sender

        let accountId = try? peerAddress.toAccountId(using: chainAssetInfo.chain)

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
        let feeValue = BigUInt(item.fee) ?? BigUInt(0)

        let precision = chainAssetInfo.asset.assetPrecision
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: precision) ?? .zero

        let fee = AssetTransactionFee(
            identifier: assetId,
            assetId: assetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = isSender ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.hash,
            status: status,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: amount,
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubscanRewardItemData,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus

        status = .commited

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.amount) ?? 0,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? .zero

        let type = TransactionType(rawValue: item.eventId.uppercased())

        return AssetTransactionData(
            transactionId: item.remoteIdentifier,
            status: status,
            assetId: assetId,
            peerId: item.extrinsicHash,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: address,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: type?.rawValue ?? "",
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubscanConcreteExtrinsicsItemData,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? .zero

        let accountId = try? address.toAccountId(using: chainAssetInfo.chain)
        let peerId = accountId?.toHex() ?? address

        let status: AssetTransactionStatus

        if let state = item.success {
            status = state ? .commited : .rejected
        } else {
            status = .pending
        }

        return AssetTransactionData(
            transactionId: item.remoteIdentifier,
            status: status,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: item.callModule,
            peerLastName: item.callFunction,
            peerName: "\(item.callModule) \(item.callFunction)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        from item: TransactionHistoryItem,
        address: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) -> AssetTransactionData {
        let selectedAssetId = chainAsset.asset.assetId

        let isTransfer = (selectedAssetId == item.assetId || selectedAssetId != utilityAsset.assetId) &&
            item.callPath.isTransfer

        if isTransfer {
            return createLocalTransfer(
                from: item,
                address: address,
                chainAsset: chainAsset,
                utilityAsset: utilityAsset
            )
        } else {
            return createLocalExtrinsic(
                from: item,
                address: address,
                chainAsset: ChainAsset(chain: chainAsset.chain, asset: utilityAsset)
            )
        }
    }

    private static func createLocalTransfer(
        from item: TransactionHistoryItem,
        address: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) -> AssetTransactionData {
        let assetId = chainAsset.chainAssetId.walletId

        let peerAddress = (item.sender == address ? item.receiver : item.sender) ?? item.sender

        let accountId = try? peerAddress.toAccountId(using: chainAsset.chain.chainFormat)

        let peerId = accountId?.toHex() ?? peerAddress

        let feeValue = item.fee.map { BigUInt($0) ?? 0 } ?? 0
        let feeDecimal = Decimal.fromSubstrateAmount(
            feeValue,
            precision: utilityAsset.displayInfo.assetPrecision
        ) ?? .zero

        let feeAssetId = ChainAsset(chain: chainAsset.chain, asset: utilityAsset).chainAssetId.walletId
        let fee = AssetTransactionFee(
            identifier: feeAssetId,
            assetId: feeAssetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amountInPlank = item.amountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createLocalExtrinsic(
        from item: TransactionHistoryItem,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let assetId = chainAsset.chainAssetId.walletId

        let feeValue = item.fee.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            feeValue,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero

        let accountId = try? item.sender.toAccountId(using: chainAsset.chain.chainFormat)

        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: item.status.walletValue,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: item.callPath.moduleName,
            peerLastName: item.callPath.callName,
            peerName: "\(item.callPath.moduleName) \(item.callPath.callName)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }
}
