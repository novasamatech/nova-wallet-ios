import Foundation
@testable import novawallet
import CommonWallet

enum AssetTransactionGenerator {
    static func generateExtrinsic(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        AssetTransactionData(
            transactionId: Data.random(of: 32)!.toHex(),
            status: .commited,
            assetId: chainAsset.chainAssetId.walletId,
            peerId: wallet.substrateAccountId!.toHex(),
            peerFirstName: "Test",
            peerLastName: "Test",
            peerName: "Test Test",
            details: "",
            amount: AmountDecimal(value: 1.0),
            fees: [],
            timestamp: Int64(Date().timeIntervalSince1970),
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: [:]
        )
    }
}
