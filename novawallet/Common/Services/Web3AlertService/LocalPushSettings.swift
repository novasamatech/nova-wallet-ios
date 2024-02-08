import Foundation
import RobinHood

struct LocalPushSettings: Codable, Equatable, Identifiable {
    let identifier: String
    var pushToken: String
    var updatedAt: Date
    let wallets: [Web3AlertWallet]
    let notifications: Web3AlertNotification

    init(from remote: RemotePushSettings, identifier: String) {
        self.identifier = identifier
        pushToken = remote.pushToken
        updatedAt = remote.updatedAt
        wallets = remote.wallets
        notifications = remote.notifications
    }

    init(
        identifier: String,
        pushToken: String,
        updatedAt: Date,
        wallets: [Web3AlertWallet],
        notifications: Web3AlertNotification
    ) {
        self.identifier = identifier
        self.pushToken = pushToken
        self.updatedAt = updatedAt
        self.wallets = wallets
        self.notifications = notifications
    }
}

// TODO: Remove
extension LocalPushSettings {
    static func createDefault(
        token: String = "",
        uuid: String? = nil,
        metaAccount: MetaAccountModel
    ) -> LocalPushSettings {
        let chainFormat = ChainFormat.substrate(UInt16(SNAddressType.polkadotMain.rawValue))
        let wallet = Web3AlertWallet(
            baseSubstrate: try? metaAccount.substrateAccountId?.toAddress(using: chainFormat),
            baseEthereum: try? metaAccount.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: [:]
        )
        return .init(
            identifier: uuid ?? UUID().uuidString,
            pushToken: token,
            updatedAt: Date(),
            wallets: [wallet],
            notifications: .init(stakingReward: .all, transfer: .all)
        )
    }
}
