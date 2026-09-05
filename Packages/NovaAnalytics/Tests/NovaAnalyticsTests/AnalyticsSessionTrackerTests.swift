import XCTest
@testable import NovaAnalytics
import Foundation_iOS

private final class ImmediateBackgroundTaskRunner: BackgroundTaskRunning {
    private(set) var beganCount = 0
    private(set) var endedCount = 0

    func run(_ work: @escaping (@escaping () -> Void) -> Void) {
        beganCount += 1
        work { self.endedCount += 1 }
    }
}

final class AnalyticsSessionTrackerTests: XCTestCase {
    private struct Fixture {
        let tracker: AnalyticsSessionTracker
        /// Holds what the tracker asked for and, crucially, the completion it was handed —
        /// so a test can decide when the flush chain "finishes".
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

    /// The enqueue and the upload are both asynchronous, so ending the system task as soon
    /// as they have been *started* releases the assertion before the session_ended row has
    /// been written — iOS then suspends the process and the event is lost.
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

        // One ordered call, not a bare track() followed by a flush(): that pair lets the
        // flush's peek run before the session_ended row exists.
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
