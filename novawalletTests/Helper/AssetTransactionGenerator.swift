import Foundation
@testable import novawallet
import CommonWallet

enum AssetTransactionGenerator {
    static func generateExtrinsic(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> TransactionHistoryItem {
        TransactionHistoryItem(
            source: .substrate,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: try! wallet.substrateAccountId!.toAddress(using: chainAsset.chain.chainFormat),
            receiver: try! AccountId.zeroAccountId(of: 32).toAddress(using: chainAsset.chain.chainFormat),
            amountInPlank: String(Decimal(1).toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)!),
            status: .success,
            txHash: Data.random(of: 32)!.toHex(),
            timestamp: Int64(Date().timeIntervalSince1970),
            fee: nil,
            blockNumber: 100, txIndex: 0,
            callPath: .transfer,
            call: nil
        )
    }
}
