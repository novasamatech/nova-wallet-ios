import Foundation

enum CloudBackupSyncState: Equatable {
    case disabled(lastSyncDate: Date?)
    case unavailable(lastSyncDate: Date?)
    case enabled(CloudBackupSyncResult?, lastSyncDate: Date?)

    var canAutoSync: Bool {
        switch self {
        case .disabled, .unavailable:
            return false
        case let .enabled(cloudBackupSyncResult, _):
            if case .noUpdates = cloudBackupSyncResult {
                return true
            } else {
                return false
            }
        }
    }
}
