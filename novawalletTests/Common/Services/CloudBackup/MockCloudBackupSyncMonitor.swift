import Foundation
@testable import novawallet

final class MockCloudBackupSyncMonitor: CloudBackupSyncMonitoring {
    func start(notifyingIn queue: DispatchQueue, with closure: @escaping CloudBackupUpdateMonitoringClosure) {}

    func stop() {}
}
