import Foundation

enum CloudBackupSyncMonitorStatus: Equatable {
    case noFile
    case notDownloaded(requested: Bool)
    case downloading(Result<Double, NSError>)
    case uploading(Result<Double, NSError>)
    case synced
}

typealias CloudBackupUpdateMonitoringClosure = (CloudBackupSyncMonitorStatus) -> Void

protocol CloudBackupSyncMonitoring {
    func start(notifyingIn queue: DispatchQueue, with closure: @escaping CloudBackupUpdateMonitoringClosure)

    func stop()
}
