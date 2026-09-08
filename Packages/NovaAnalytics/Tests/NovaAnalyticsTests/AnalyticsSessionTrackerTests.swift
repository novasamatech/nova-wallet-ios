import XCTest
@testable import NovaAnalytics
import Foundation_iOS

final class AnalyticsSessionTrackerTests: XCTestCase {
    private struct Fixture {
        let tracker: AnalyticsSessionTracker
        let recorder: AnalyticsTrackingSpy
        let runner: ImmediateBackgroundTaskRunner
    }

    private func makeFixture(now: @escaping () -> Date = { Date() }) -> Fixture {
        let recorder = AnalyticsTrackingSpy()
        let runner = ImmediateBackgroundTaskRunner()

        let tracker = AnalyticsSessionTracker(
            tracker: recorder,
            applicationHandler: ApplicationHandler(),
            backgroundTaskRunner: runner,
            timeProvider: now
        )

        return Fixture(tracker: tracker, recorder: recorder, runner: runner)
    }

    private func enterBackground(_ fixture: Fixture) {
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))
    }

    func testSetupStartsASession() {
        let fixture = makeFixture()
        fixture.tracker.startSession()

        XCTAssertEqual(fixture.recorder.eventNames, ["session_started"])
    }

    func testForegroundStartsAnotherSession() {
        let fixture = makeFixture()
        fixture.tracker.startSession()
        fixture.tracker.didReceiveWillEnterForeground(notification: .init(name: .init("test")))

        XCTAssertEqual(fixture.recorder.eventNames, ["session_started", "session_started"])
    }

    func testBackgroundEndsTheSessionWithADurationBucketAndFlushes() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFixture(now: { now })

        fixture.tracker.startSession()
        now = now.addingTimeInterval(42)
        enterBackground(fixture)

        XCTAssertEqual(fixture.recorder.eventNames, ["session_started", "session_ended"])
        XCTAssertEqual(fixture.recorder.flushReasons, [.background])
        XCTAssertEqual(
            fixture.recorder.events.last?.properties[.durationBucket],
            .enumerated(DurationBucket.from30sTo60s.rawValue)
        )
    }

    func testBackgroundWithoutAStartEmitsNothing() {
        let fixture = makeFixture()
        enterBackground(fixture)

        XCTAssertTrue(fixture.recorder.events.isEmpty)
        XCTAssertTrue(fixture.recorder.flushReasons.isEmpty)
    }

    func testTheBackgroundTaskOutlivesTheWorkItBrackets() {
        let fixture = makeFixture()
        fixture.tracker.startSession()

        enterBackground(fixture)

        XCTAssertEqual(fixture.runner.beganCount, 1)
        XCTAssertEqual(
            fixture.runner.endedCount,
            0,
            "the background assertion was released while the flush was still running"
        )

        fixture.recorder.finishPendingFlushes()

        XCTAssertEqual(fixture.runner.endedCount, 1)
    }

    func testTheSessionEndIsOrderedAheadOfTheFlushThatCarriesIt() {
        let fixture = makeFixture()
        fixture.tracker.startSession()

        enterBackground(fixture)

        XCTAssertEqual(fixture.recorder.pendingCompletions.count, 1)
        XCTAssertEqual(fixture.recorder.eventNames.last, "session_ended")

        XCTAssertEqual(fixture.recorder.trackedEvents.count, 1)
        XCTAssertEqual(fixture.recorder.trackedEvents.last?.name.rawValue, "session_started")
    }

    func testConsecutiveBackgroundsEmitOnlyOneEnd() {
        let fixture = makeFixture()
        fixture.tracker.startSession()
        enterBackground(fixture)
        enterBackground(fixture)

        XCTAssertEqual(fixture.recorder.eventNames, ["session_started", "session_ended"])
    }
}
