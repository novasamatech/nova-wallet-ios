import Foundation
@testable import novawallet

enum AssetTransactionGenerator {
    static func generateExtrinsic(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> TransactionHistoryItem {
        let hash = Data.random(of: 32)!.toHexWithPrefix()
        let source = TransactionHistoryItemSource.substrate

        return TransactionHistoryItem(
            identifier: TransactionHistoryItem.createIdentifier(from: hash, source: source),
            source: source,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: try! wallet.substrateAccountId!.toAddress(using: chainAsset.chain.chainFormat),
            receiver: try! AccountId.zeroAccountId(of: 32).toAddress(using: chainAsset.chain.chainFormat),
            amountInPlank: String(Decimal(1).toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)!),
            status: .success,
            txHash: hash,
            timestamp: Int64(Date().timeIntervalSince1970),
            fee: nil,
            feeAssetId: nil,
            blockNumber: 100, txIndex: 0,
            callPath: .transfer,
            call: nil,
            swap: nil
        )
    }
}
