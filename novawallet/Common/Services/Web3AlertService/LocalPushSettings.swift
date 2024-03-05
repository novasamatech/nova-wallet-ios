import Foundation
import RobinHood

struct LocalPushSettings: Codable, Equatable, Identifiable {
    var identifier: String { Self.getIdentifier() }
    let remoteIdentifier: String
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

extension LocalPushSettings {
    func with(_ modifier: (inout Web3AlertNotification) -> Void) -> LocalPushSettings {
        var editedNotifications = notifications
        modifier(&editedNotifications)

        return .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: updatedAt,
            wallets: wallets,
            notifications: editedNotifications
        )
    }

    func with(wallets: [Web3AlertWallet]) -> LocalPushSettings {
        .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: updatedAt,
            wallets: wallets,
            notifications: notifications
        )
    }
}
