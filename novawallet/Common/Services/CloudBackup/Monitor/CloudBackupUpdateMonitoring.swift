import Foundation

enum CloudBackupUpdateMonitorError: Error {
    case internalError(Error)
}

enum CloudBackupUpdateStatus {
    case noFile
    case downloaded
    case notDownloaded
    case unknown
}

typealias CloudBackupUpdateMonitoringClosure = (Result<CloudBackupUpdateStatus, CloudBackupUpdateMonitorError>) -> Void

protocol CloudBackupUpdateMonitoring {
    func start(with closure: @escaping CloudBackupUpdateMonitoringClosure)

    func stop()
}
