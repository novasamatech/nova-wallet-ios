import Foundation
import SoraKeystore

protocol CloudBackupSyncMetadataManaging {
    func getLastSyncDate() -> Date?
    func saveLastSyncDate(_ newDate: Date?)
    func hasLastSyncDate() -> Bool
    
    func getPassword() throws -> String?
    func savePassword(_ newValue: String?) throws
    func hasPassword() throws -> Bool
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
    func getLastSyncDate() -> Date? {
        let timestamp = settings.lastCloudBackupTimestampSeen
        
        return timestamp.map { Date(timeIntervalSince1970: timestamp) }
    }
    
    func saveLastSyncDate(_ newDate: Date?) {
        settings.lastCloudBackupTimestampSeen = newDate?.timeIntervalSince1970
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
        let rawData = newValue?.data(using: .utf8)
        try keystore.saveKey(rawData, with: KeystoreTagV2.cloudBackupPassword.rawValue)
    }
    
    func hasPassword() -> Bool {
        try keystore.checkKey(for: KeystoreTagV2.cloudBackupPassword.rawValue)
    }
}
