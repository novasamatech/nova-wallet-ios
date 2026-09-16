import Foundation
@testable import NovaAnalytics

final class ImmediateBackgroundTaskRunner: BackgroundTaskRunning {
    func run(_ work: @escaping (@escaping () -> Void) -> Void) {
        work {}
    }
}
