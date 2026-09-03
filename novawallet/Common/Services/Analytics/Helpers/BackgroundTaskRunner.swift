import UIKit

final class UIApplicationBackgroundTaskRunner {
    private let application: UIApplication

    init(application: UIApplication = .shared) {
        self.application = application
    }
}

// MARK: - BackgroundTaskRunning

extension UIApplicationBackgroundTaskRunner: BackgroundTaskRunning {
    func run(_ work: @escaping (@escaping () -> Void) -> Void) {
        var identifier: UIBackgroundTaskIdentifier = .invalid
        let mutex = NSLock()

        let end: () -> Void = { [weak application] in
            mutex.lock()

            defer {
                mutex.unlock()
            }

            guard identifier != .invalid else {
                return
            }

            application?.endBackgroundTask(identifier)
            identifier = .invalid
        }

        identifier = application.beginBackgroundTask(withName: "io.novawallet.analytics.flush") {
            end()
        }

        work(end)
    }
}
