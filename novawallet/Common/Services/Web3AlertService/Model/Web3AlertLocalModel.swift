import Foundation
import Operation_iOS

extension Web3Alert {
    typealias LocalNotifications = Web3Alert.Notifications<Set<Web3Alert.LocalChainId>>

    struct LocalSettings: Codable, Equatable, Identifiable {
        var identifier: String { Self.getIdentifier() }
        let remoteIdentifier: String
        let pushToken: String
        let updatedAt: Date
        let wallets: [LocalWallet]
        let notifications: LocalNotifications

        init(
            remoteIdentifier: String,
            pushToken: String,
            updatedAt: Date,
            wallets: [LocalWallet],
            notifications: LocalNotifications
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
        let model: Web3Alert.Wallet<Web3Alert.LocalChainId>
    }
}

extension Web3Alert.LocalSettings {
    func settingCurrentDate() -> Web3Alert.LocalSettings {
        .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: Date(),
            wallets: wallets,
            notifications: notifications
        )
    }

    func updating(date: Date) -> Web3Alert.LocalSettings {
        .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: date,
            wallets: wallets,
            notifications: notifications
        )
    }

    func updating(pushToken: String) -> Web3Alert.LocalSettings {
        .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: updatedAt,
            wallets: wallets,
            notifications: notifications
        )
    }

    func with(_ modifier: (inout Web3Alert.LocalNotifications) -> Void) -> Web3Alert.LocalSettings {
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

    func updating(with wallets: [Web3Alert.LocalWallet]) -> Web3Alert.LocalSettings {
        var updatedWalletsMap = self.wallets.reduce(into: [MetaAccountModel.Id: Web3Alert.LocalWallet]()) {
            $0[$1.metaId] = $1
        }

        wallets.forEach {
            updatedWalletsMap[$0.metaId] = $0
        }

        return .init(
            remoteIdentifier: remoteIdentifier,
            pushToken: pushToken,
            updatedAt: updatedAt,
            wallets: Array(updatedWalletsMap.values),
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

extension Web3Alert.Selection where T == Set<Web3Alert.LocalChainId> {
    var notificationsEnabled: Bool {
        switch self {
        case .all:
            return true
        case let .concrete(value):
            return !value.isEmpty
        }
    }
}

extension Optional where Wrapped == Web3Alert.Selection<Set<Web3Alert.LocalChainId>> {
    mutating func toggle() {
        switch self {
        case .none:
            self = .all
        case .all:
            self = nil
        case .concrete:
            self = nil
        }
    }
}
