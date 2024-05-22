import Foundation
@testable import novawallet

final class MockCloudBackupStorageManager {
    let result: Result<Void, CloudBackupUploadError>
    
    init(result: Result<Void, CloudBackupUploadError> = .success(())) {
        self.result = result
    }
}

extension MockCloudBackupStorageManager: CloudBackupStorageManaging {
    func checkStorage(
        of size: UInt64,
        timeoutInterval: TimeInterval,
        runningIn queue: DispatchQueue,
        completionClosure: @escaping CloudBackupUploadMonitoringClosure
    ) {
        dispatchInQueueWhenPossible(queue) {
            completionClosure(self.result)
        }
    }
}
