import Foundation
import RobinHood

extension Web3Alert {
    struct LocalSettings: Codable, Equatable, Identifiable {
        var identifier: String { Self.getIdentifier() }
        let remoteIdentifier: String
        var pushToken: String
        var updatedAt: Date
        let wallets: [LocalWallet]
        let notifications: Web3Alert.Notifications

        init(
            remoteIdentifier: String,
            pushToken: String,
            updatedAt: Date,
            wallets: [LocalWallet],
            notifications: Web3Alert.Notifications
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

    struct LocalWallet: Codable, Equatable {
        let metaId: MetaAccountModel.Id
        let remoteModel: Web3Alert.Wallet
    }
}

extension Web3Alert.LocalSettings {
    func with(_ modifier: (inout Web3Alert.Notifications) -> Void) -> Web3Alert.LocalSettings {
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

    func with(wallets: [Web3Alert.LocalWallet]) -> Web3Alert.LocalSettings {
        .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: updatedAt,
            wallets: wallets,
            notifications: notifications
        )
    }

    func updatingMetadata(from other: Web3Alert.LocalSettings) -> Web3Alert.LocalSettings {
        .init(
            remoteIdentifier: other.remoteIdentifier,
            pushToken: other.pushToken,
            updatedAt: other.updatedAt,
            wallets: wallets,
            notifications: notifications
        )
    }
}
