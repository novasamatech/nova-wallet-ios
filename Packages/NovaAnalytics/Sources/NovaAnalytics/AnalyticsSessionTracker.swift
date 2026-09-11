import Foundation
import Foundation_iOS

/// A session is one foreground period.
public final class AnalyticsSessionTracker {
    private let tracker: AnalyticsTrackingProtocol
    private let applicationHandler: ApplicationHandlerProtocol
    private let backgroundTaskRunner: BackgroundTaskRunning
    private let timeProvider: () -> Date

    private let mutex = NSLock()
    private var sessionStartedAt: Date?

    public init(
        tracker: AnalyticsTrackingProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        backgroundTaskRunner: BackgroundTaskRunning,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.tracker = tracker
        self.applicationHandler = applicationHandler
        self.backgroundTaskRunner = backgroundTaskRunner
        self.timeProvider = timeProvider
    }
}

// MARK: - AnalyticsSessionTracking

extension AnalyticsSessionTracker: AnalyticsSessionTracking {
    public func setup() {
        applicationHandler.delegate = self
    }

    public func throttle() {
        applicationHandler.delegate = nil
    }

    public func startSession() {
        mutex.lock()
        sessionStartedAt = timeProvider()
        mutex.unlock()

        tracker.track(.sessionStarted())
    }
}

// MARK: - ApplicationHandlerDelegate

extension AnalyticsSessionTracker: ApplicationHandlerDelegate {
    public func didReceiveWillEnterForeground(notification _: Notification) {
        startSession()
    }

    public func didReceiveDidEnterBackground(notification _: Notification) {
        mutex.lock()
        let startedAt = sessionStartedAt
        sessionStartedAt = nil
        mutex.unlock()

        guard let startedAt else {
            return
        }

        let duration = timeProvider().timeIntervalSince(startedAt)

        backgroundTaskRunner.run { [weak self] completion in
            guard let self else {
                completion()
                return
            }

            tracker.trackAndFlush(
                .sessionEnded(duration: duration),
                reason: .background,
                completion: completion
            )
        }
    }

    public func didReceiveWillResignActive(notification _: Notification) {}

    public func didReceiveDidBecomeActive(notification _: Notification) {}
}
