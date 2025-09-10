import Foundation
@testable import novawallet

final class MockCloudBackupSyncMonitor: CloudBackupSyncMonitoring {
    func start(notifyingIn _: DispatchQueue, with _: @escaping CloudBackupUpdateMonitoringClosure) {}

    func stop() {}
}
