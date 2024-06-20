import Foundation

struct CloudBackupSettingsViewModel {
    enum Status {
        case disabled
        case syncing
        case unavailable
        case unsynced
        case synced

        var isEnabled: Bool {
            switch self {
            case .disabled:
                return false
            case .syncing, .synced, .unsynced, .unavailable:
                return true
            }
        }

        var isSyncing: Bool {
            switch self {
            case .syncing:
                return true
            case .disabled, .synced, .unsynced, .unavailable:
                return false
            }
        }
    }

    let status: Status
    let title: String
    let lastSynced: String?
    let issue: String?
}
