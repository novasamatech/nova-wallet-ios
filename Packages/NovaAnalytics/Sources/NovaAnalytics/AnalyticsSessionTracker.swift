import Foundation
import Foundation_iOS

/// A session is a foreground period, the closest match to Android's
/// `ProcessLifecycleOwner.onStart/onStop`.
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

    /// Cold start: willEnterForeground is not posted on launch, so the facade calls this.
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

        // `track` and `flush` both return the moment their operations are enqueued, so
        // ending the system task after calling them released the background assertion
        // before the session_ended row had been written — iOS then suspended the process
        // and the event was lost. `trackAndFlush` fires the completion only once both the
        // enqueue and the flush chain have settled.
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

    /// Deliberately ignored: it fires for Control Centre, the Face ID sheet and incoming
    /// calls, none of which end a session. The security layer already uses it for the
    /// privacy overlay.
    public func didReceiveWillResignActive(notification _: Notification) {}

    /// Deliberately ignored, as the counterpart of `didReceiveWillResignActive`: a session
    /// starts on foreground, not on regaining first-responder-style activity.
    public func didReceiveDidBecomeActive(notification _: Notification) {}
}
