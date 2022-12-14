import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import SubstrateSdk

extension AssetTransactionData {
    static func createTransaction(
        from item: TransactionHistoryItem,
        address: String,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel
    ) -> AssetTransactionData {
        let selectedAssetId = chainAsset.asset.assetId

        let isTransfer = (selectedAssetId == item.assetId || selectedAssetId != utilityAsset.assetId) &&
            item.callPath.isSubstrateOrEvmTransfer

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
