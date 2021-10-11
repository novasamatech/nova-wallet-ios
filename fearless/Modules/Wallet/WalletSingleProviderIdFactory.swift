import Foundation
import CommonWallet
import IrohaCrypto

final class WalletSingleProviderIdFactory: SingleProviderIdentifierFactoryProtocol {
    func balanceIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).balance"
    }

    func historyIdentifierForAccountId(_ accountId: String, assets _: [String]) -> String {
        "wallet.cache.\(accountId).history"
    }

    func contactsIdentifierForAccountId(_ accountId: String) -> String {
        "wallet.cache.\(accountId).contacts"
    }

    func withdrawMetadataIdentifierForAccountId(
        _ accountId: String,
        assetId: String,
        optionId _: String
    ) -> String {
        "wallet.cache.\(accountId).\(assetId).withdraw.metadata"
    }

    func transferMetadataIdentifierForAccountId(
        _ accountId: String,
        assetId: String,
        receiverId _: String
    ) -> String {
        "wallet.cache.\(accountId).\(assetId).transfer.metadata"
    }
}
