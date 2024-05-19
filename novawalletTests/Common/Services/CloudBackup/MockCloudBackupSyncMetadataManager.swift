import Foundation
@testable import novawallet

final class MockCloudBackupSyncMetadataManager {
    @Atomic var isBackupEnabled: Bool
    @Atomic private var lastSyncDate: UInt64?
    @Atomic private var password: String?
    
    init(isBackupEnabled: Bool = false, lastSyncDate: UInt64? = nil, password: String? = nil) {
        self._isBackupEnabled = Atomic(defaultValue: isBackupEnabled)
        self._lastSyncDate = Atomic(defaultValue: lastSyncDate)
        self._password = Atomic(defaultValue: password)
    }
}

extension MockCloudBackupSyncMetadataManager: CloudBackupSyncMetadataManaging {
    func getLastSyncDate() -> UInt64? {
        lastSyncDate
    }
    
    func saveLastSyncDate(_ newDate: UInt64?) {
        lastSyncDate = newDate
    }
    
    func hasLastSyncDate() -> Bool {
        lastSyncDate != nil
    }

    func getPassword() throws -> String? {
        password
    }
    
    func savePassword(_ newValue: String?) throws {
        self.password = newValue
    }
    
    func hasPassword() throws -> Bool {
        password != nil
    }
}
