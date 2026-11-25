import UIKit

protocol BackgroundTimeKeeping: AnyObject {
    func keepAwake(until date: Date)
    func keepAwakeIfInBackground(until date: Date)
    func release()
    func release(when isIdle: @escaping () -> Bool)
}

final class BackgroundTimeKeeper {
    let logger: LoggerProtocol

    private var taskId: UIBackgroundTaskIdentifier = .invalid
    private var keepUntil: Date?

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

// MARK: - BackgroundTimeKeeping

extension BackgroundTimeKeeper: BackgroundTimeKeeping {
    func keepAwake(until date: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.extend(until: date)
        }
    }

    func keepAwakeIfInBackground(until date: Date) {
        DispatchQueue.main.async { [weak self] in
            guard UIApplication.shared.applicationState == .background else {
                return
            }

            self?.extend(until: date)
        }
    }

    func release() {
        release { true }
    }

    func release(when isIdle: @escaping () -> Bool) {
        DispatchQueue.main.async { [weak self] in
            guard isIdle() else {
                return
            }

            self?.keepUntil = nil
            self?.end(reason: "released")
        }
    }
}

// MARK: - Private

private extension BackgroundTimeKeeper {
    enum Constants {
        static let taskName = "io.novawallet.transaction.tracking"
    }

    func extend(until date: Date) {
        guard date > Date() else {
            return
        }

        keepUntil = max(keepUntil ?? date, date)

        begin()

        DispatchQueue.main.asyncAfter(deadline: .now() + date.timeIntervalSinceNow) { [weak self] in
            guard let self, let keepUntil, keepUntil <= date else {
                return
            }

            end(reason: "window ended")
        }
    }

    func begin() {
        guard taskId == .invalid else {
            return
        }

        taskId = UIApplication.shared.beginBackgroundTask(withName: Constants.taskName) { [weak self] in
            // Must end synchronously: iOS kills an app whose expired background task is still running.
            self?.end(reason: "expired")
        }

        logger.debug("Tracking: background time started")
    }

    func end(reason: String) {
        guard taskId != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(taskId)
        taskId = .invalid

        logger.debug("Tracking: background time \(reason)")
    }
}
