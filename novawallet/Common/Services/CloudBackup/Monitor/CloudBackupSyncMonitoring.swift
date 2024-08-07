import Foundation

enum CloudBackupSyncMonitorStatus: Equatable {
    case noFile
    case notDownloaded(requested: Bool)
    case downloading(Result<Double, NSError>)
    case uploading(Result<Double, NSError>)
    case synced

    var isDowndloading: Bool {
        switch self {
        case .notDownloaded, .downloading:
            return true
        case .noFile, .synced, .uploading:
            return false
        }
    }

    var isSyncing: Bool {
        switch self {
        case .synced, .noFile:
            return false
        case .notDownloaded, .downloading, .uploading:
            return true
        }
    }
}

typealias CloudBackupUpdateMonitoringClosure = (CloudBackupSyncMonitorStatus) -> Void

protocol CloudBackupSyncMonitoring {
    func start(notifyingIn queue: DispatchQueue, with closure: @escaping CloudBackupUpdateMonitoringClosure)

    func stop()
}
