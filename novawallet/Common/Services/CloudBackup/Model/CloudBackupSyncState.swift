import Foundation

enum CloudBackupSyncState: Equatable {
    case disabled(lastSyncDate: Date?)
    case unavailable(lastSyncDate: Date?)
    case enabled(CloudBackupSyncResult?, lastSyncDate: Date?)
}
