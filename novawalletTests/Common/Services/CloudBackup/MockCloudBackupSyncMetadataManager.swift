import Foundation
@testable import novawallet

final class MockCloudBackupSyncMetadataManager {
    @Atomic var isBackupEnabled: Bool
    @Atomic private var lastSyncDate: UInt64?
    @Atomic private var password: String?

    init(isBackupEnabled: Bool = false, lastSyncDate: UInt64? = nil, password: String? = nil) {
        _isBackupEnabled = Atomic(defaultValue: isBackupEnabled)
        _lastSyncDate = Atomic(defaultValue: lastSyncDate)
        _password = Atomic(defaultValue: password)
    }
}

extension MockCloudBackupSyncMetadataManager: CloudBackupSyncMetadataManaging {
    func getLastSyncTimestamp() -> UInt64? {
        lastSyncDate
    }

    func saveLastSyncTimestamp(_ newDate: UInt64?) {
        lastSyncDate = newDate
    }

    func hasLastSyncTimestamp() -> Bool {
        lastSyncDate != nil
    }

    func getPassword() throws -> String? {
        password
    }

    func savePassword(_ newValue: String?) throws {
        password = newValue
    }

    func hasPassword() throws -> Bool {
        password != nil
    }

    func setNotifyIncreaseSecurity() {}
}
