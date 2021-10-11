import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import FearlessUtils

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

        let peerAddress = item.sender == address ? item.receiver : item.sender

        let accountId = try? peerAddress.toAccountId(using: chainAssetInfo.chain)

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
        let feeValue = BigUInt(item.fee) ?? BigUInt(0)
        let feeDecimal = Decimal.fromSubstrateAmount(
            feeValue,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? .zero

        let fee = AssetTransactionFee(
            identifier: assetId,
            assetId: assetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = item.sender == address ? TransactionType.outgoing :
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
            transactionId: item.identifier,
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
            transactionId: item.identifier,
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
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        if item.callPath.isTransfer {
            return createLocalTransfer(
                from: item,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        } else {
            return createLocalExtrinsic(
                from: item,
                address: address,
                assetId: assetId,
                chainAssetInfo: chainAssetInfo
            )
        }
    }

    private static func createLocalTransfer(
        from item: TransactionHistoryItem,
        address: String,
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let peerAddress = (item.sender == address ? item.receiver : item.sender) ?? item.sender

        let accountId = try? peerAddress.toAccountId(using: chainAssetInfo.chain)

        let peerId = accountId?.toHex() ?? peerAddress

        let feeDecimal = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? .zero

        let fee = AssetTransactionFee(
            identifier: assetId,
            assetId: assetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amount: Decimal = {
            if let encodedCall = item.call,
               let call = try? JSONDecoder.scaleCompatible()
               .decode(RuntimeCall<TransferCall>.self, from: encodedCall) {
                return Decimal.fromSubstrateAmount(
                    call.args.value,
                    precision: chainAssetInfo.asset.assetPrecision
                ) ?? .zero
            } else {
                return .zero
            }
        }()

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
        assetId: String,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: chainAssetInfo.asset.assetPrecision
        ) ?? .zero

        let accountId = try? item.sender.toAccountId(using: chainAssetInfo.chain)

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
