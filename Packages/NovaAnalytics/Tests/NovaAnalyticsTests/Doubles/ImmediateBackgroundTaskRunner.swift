import Foundation
@testable import NovaAnalytics

final class ImmediateBackgroundTaskRunner: BackgroundTaskRunning {
    private(set) var beganCount = 0
    private(set) var endedCount = 0

    func run(_ work: @escaping (@escaping () -> Void) -> Void) {
        beganCount += 1
        work { self.endedCount += 1 }
    }
}
