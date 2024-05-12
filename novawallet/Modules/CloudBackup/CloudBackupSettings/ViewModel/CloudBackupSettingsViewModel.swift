import Foundation

struct CloudBackupSettingsViewModel {
    enum Status {
        case disabled
        case syncing
        case unsynced
        case synced
    }

    let status: Status
    let title: String
    let lastSynced: String?
    let issue: String?
}
