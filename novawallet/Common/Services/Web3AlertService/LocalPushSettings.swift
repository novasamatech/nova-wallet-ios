import Foundation
import RobinHood

struct LocalPushSettings: Codable, Equatable, Identifiable {
    var identifier: String { Self.getIdentifier() }
    var remoteIdentifier: String
    var pushToken: String
    var updatedAt: Date
    let wallets: [Web3AlertWallet]
    let notifications: Web3AlertNotification

    init(
        remoteIdentifier: String,
        pushToken: String,
        updatedAt: Date,
        wallets: [Web3AlertWallet],
        notifications: Web3AlertNotification
    ) {
        self.remoteIdentifier = remoteIdentifier
        self.pushToken = pushToken
        self.updatedAt = updatedAt
        self.wallets = wallets
        self.notifications = notifications
    }

    static func getIdentifier() -> String {
        "LocalPushSettingsIdentifier"
    }
}
