import Foundation
import Keystore_iOS

protocol CloudBackupSyncMetadataManaging: AnyObject {
    func getLastSyncTimestamp() -> UInt64?
    func saveLastSyncTimestamp(_ newDate: UInt64?)
    func hasLastSyncTimestamp() -> Bool

    func getPassword() throws -> String?
    func savePassword(_ newValue: String?) throws
    func hasPassword() throws -> Bool

    var isBackupEnabled: Bool { get set }
}

extension CloudBackupSyncMetadataManaging {
    func getLastSyncDate() -> Date? {
        getLastSyncTimestamp().map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    func enableBackup(for password: String?) throws {
        try savePassword(password)

        saveLastSyncTimestamp(UInt64(Date().timeIntervalSince1970))
        isBackupEnabled = true
    }

    func deleteBackup() throws {
        saveLastSyncTimestamp(nil)
        isBackupEnabled = false

        try savePassword(nil)
    }
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

    private func getOrCreatePasswordId() -> String {
        if let passwordId = settings.cloudBackupPasswordId {
            return passwordId
        }

        let passwordId = UUID().uuidString

        settings.cloudBackupPasswordId = passwordId

        return passwordId
    }
}

extension CloudBackupSyncMetadataManager: CloudBackupSyncMetadataManaging {
    var isBackupEnabled: Bool {
        get {
            settings.isCloudBackupEnabled
        }

        set {
            settings.isCloudBackupEnabled = newValue
        }
    }

    func getLastSyncTimestamp() -> UInt64? {
        settings.lastCloudBackupTimestampSeen
    }

    func saveLastSyncTimestamp(_ newDate: UInt64?) {
        settings.lastCloudBackupTimestampSeen = newDate
    }

    func hasLastSyncTimestamp() -> Bool {
        settings.lastCloudBackupTimestampSeen != nil
    }

    func getPassword() throws -> String? {
        let passwordId = getOrCreatePasswordId()

        let tag = KeystoreTagV2.cloudBackupPasswordTag(for: passwordId)
        guard let rawData = try keystore.loadIfKeyExists(tag) else {
            return nil
        }

        return String(data: rawData, encoding: .utf8)
    }

    func savePassword(_ newValue: String?) throws {
        let passwordId = getOrCreatePasswordId()
        let tag = KeystoreTagV2.cloudBackupPasswordTag(for: passwordId)

        if let password = newValue {
            guard let rawData = password.data(using: .utf8) else {
                throw CloudBackupSyncMetadataManagingError.badArgument
            }

            try keystore.saveKey(rawData, with: tag)
        } else {
            try keystore.deleteKeyIfExists(for: tag)
        }
    }

    func hasPassword() throws -> Bool {
        let passwordId = getOrCreatePasswordId()
        let tag = KeystoreTagV2.cloudBackupPasswordTag(for: passwordId)
        return try keystore.checkKey(for: tag)
    }
}
