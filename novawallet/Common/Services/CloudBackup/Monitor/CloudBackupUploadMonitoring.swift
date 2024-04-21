import Foundation

enum CloudBackupUploadError: Error {
    case notEnoughSpace
    case timeout
    case internalError(Error)
}

typealias CloudBackupUploadMonitoringClosure = (Result<Void, CloudBackupUploadError>) -> Void

protocol CloudBackupUploadMonitoring {
    func start(with closure: @escaping CloudBackupUploadMonitoringClosure)

    func stop()
}
