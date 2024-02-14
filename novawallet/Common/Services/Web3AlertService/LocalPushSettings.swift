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
