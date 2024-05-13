import Foundation
import SoraKeystore

protocol CloudBackupSyncMetadataManaging {
    func getLastSyncDate() -> UInt64?
    func saveLastSyncDate(_ newDate: UInt64?)
    func hasLastSyncDate() -> Bool

    func getPassword() throws -> String?
    func savePassword(_ newValue: String?) throws
    func hasPassword() throws -> Bool
}

enum CloudBackupSyncMetadataManagingError: Error {
    case badArgument
}

final class CloudBackupSyncMetadataManager {
    let settings: SettingsManagerProtocol
    let keystore: KeystoreProtocol

    init(settings: SettingsManagerProtocol, keystore: KeystoreProtocol) {
        self.settings = settings
        self.keystore = keystore
    }
}

extension CloudBackupSyncMetadataManager: CloudBackupSyncMetadataManaging {
    func getLastSyncDate() -> UInt64? {
        settings.lastCloudBackupTimestampSeen
    }

    func saveLastSyncDate(_ newDate: UInt64?) {
        settings.lastCloudBackupTimestampSeen = newDate
    }

    func hasLastSyncDate() -> Bool {
        settings.lastCloudBackupTimestampSeen != nil
    }

    func getPassword() throws -> String? {
        guard let rawData = try keystore.loadIfKeyExists(KeystoreTagV2.cloudBackupPassword.rawValue) else {
            return nil
        }

        return String(data: rawData, encoding: .utf8)
    }

    func savePassword(_ newValue: String?) throws {
        if let password = newValue {
            guard let rawData = password.data(using: .utf8) else {
                throw CloudBackupSyncMetadataManagingError.badArgument
            }

            try keystore.saveKey(rawData, with: KeystoreTagV2.cloudBackupPassword.rawValue)
        } else {
            try keystore.deleteKeyIfExists(for: KeystoreTagV2.cloudBackupPassword.rawValue)
        }
    }

    func hasPassword() throws -> Bool {
        try keystore.checkKey(for: KeystoreTagV2.cloudBackupPassword.rawValue)
    }
}
