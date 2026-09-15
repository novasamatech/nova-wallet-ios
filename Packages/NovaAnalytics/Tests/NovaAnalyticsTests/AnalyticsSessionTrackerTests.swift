import XCTest
@testable import NovaAnalytics

final class AnalyticsSessionTrackerTests: XCTestCase {
    private func makeTracker(
        recorder: AnalyticsTrackingSpy,
        now: @escaping () -> Date = { Date() }
    ) -> AnalyticsSessionTracker {
        AnalyticsSessionTracker(
            tracker: recorder,
            applicationHandler: ApplicationHandlerStub(),
            backgroundTaskRunner: ImmediateBackgroundTaskRunner(),
            timeProvider: now
        )
    }

    func testStartSessionTracksEvent() {
        let recorder = AnalyticsTrackingSpy()
        let tracker = makeTracker(recorder: recorder)

        tracker.startSession()

        XCTAssertEqual(recorder.eventNames, ["session_started"])
    }

    func testBackgroundTracksDurationAndFlushes() {
        var now = Date(timeIntervalSince1970: 0)
        let recorder = AnalyticsTrackingSpy()
        let tracker = makeTracker(recorder: recorder, now: { now })

        tracker.startSession()
        now = now.addingTimeInterval(42)
        tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))

        XCTAssertEqual(recorder.eventNames, ["session_started", "session_ended"])
        XCTAssertEqual(recorder.flushReasons, [.background])
        XCTAssertEqual(
            recorder.events.last?.properties[.durationBucket],
            .enumerated(DurationBucket.from30sTo60s.rawValue)
        )
    }
}
