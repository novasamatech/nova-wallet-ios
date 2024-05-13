import Foundation

enum CloudBackupSyncState: Equatable {
    case disabled
    case unavailable
    case enabled(CloudBackupSyncResult?)
}
