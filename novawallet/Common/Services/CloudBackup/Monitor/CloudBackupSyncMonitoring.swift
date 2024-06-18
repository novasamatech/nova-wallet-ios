import Foundation

enum CloudBackupSyncMonitorStatus {
    case noFile
    case notDownloaded(requested: Bool)
    case downloading(Result<Double, Error>)
    case uploading(Result<Double, Error>)
    case synced
}

typealias CloudBackupUpdateMonitoringClosure = (CloudBackupSyncMonitorStatus) -> Void

protocol CloudBackupSyncMonitoring {
    func start(notifyingIn queue: DispatchQueue, with closure: @escaping CloudBackupUpdateMonitoringClosure)

    func stop()
}
