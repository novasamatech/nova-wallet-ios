import Foundation

enum CloudBackupSyncState: Equatable {
    case disabled(lastSyncDate: Date?)
    case unavailable(lastSyncDate: Date?)
    case enabled(CloudBackupSyncResult?, lastSyncDate: Date?)

    var canAutoSync: Bool {
        switch self {
        case .disabled, .unavailable:
            return false
        case .enabled:
            return true
        }
    }

    var changes: CloudBackupSyncResult.Changes? {
        guard case let .enabled(cloudBackupSyncResult, _) = self else {
            return nil
        }

        switch cloudBackupSyncResult {
        case let .changes(changes):
            return changes
        case .issue, .noUpdates, .none:
            return nil
        }
    }

    var isSyncing: Bool {
        if case let .enabled(cloudBackupSyncResult, _) = self, cloudBackupSyncResult == nil {
            return true
        } else {
            return false
        }
    }
}
