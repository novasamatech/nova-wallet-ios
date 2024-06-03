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
}
