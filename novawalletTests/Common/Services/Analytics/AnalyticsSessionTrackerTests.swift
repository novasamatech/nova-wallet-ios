import XCTest
@testable import novawallet
import Foundation_iOS
import Cuckoo

private final class ImmediateBackgroundTaskRunner: BackgroundTaskRunning {
    private(set) var beganCount = 0
    private(set) var endedCount = 0

    func run(_ work: @escaping (@escaping () -> Void) -> Void) {
        beganCount += 1
        work { self.endedCount += 1 }
    }
}

final class AnalyticsSessionTrackerTests: XCTestCase {
    final class FlushBox {
        var value: [AnalyticsFlushReason] = []
    }

    private struct Fixture {
        let tracker: AnalyticsSessionTracker
        let analytics: MockAnalyticsTrackingProtocol
        let runner: ImmediateBackgroundTaskRunner
        let flushBox: FlushBox

        var flushReasons: [AnalyticsFlushReason] { flushBox.value }
    }

    private func makeFixture(now: @escaping () -> Date = { Date() }) -> Fixture {
        let analytics = MockAnalyticsTrackingProtocol()
        stub(analytics) { stub in
            when(stub.track(any())).thenDoNothing()
        }

        let runner = ImmediateBackgroundTaskRunner()
        let box = FlushBox()

        let tracker = AnalyticsSessionTracker(
            tracker: analytics,
            flushHandler: { box.value.append($0) },
            applicationHandler: ApplicationHandler(),
            backgroundTaskRunner: runner,
            timeProvider: now
        )

        return Fixture(tracker: tracker, analytics: analytics, runner: runner, flushBox: box)
    }

    private func trackedNames(_ fixture: Fixture) -> [String] {
        let captor = ArgumentCaptor<AnalyticsEvent>()
        verify(fixture.analytics, atLeastOnce()).track(captor.capture())

        return captor.allValues.map(\.name.rawValue)
    }

    func testSetupStartsASession() {
        let fixture = makeFixture()
        fixture.tracker.startSession()

        XCTAssertEqual(trackedNames(fixture), ["session_started"])
    }

    func testForegroundStartsAnotherSession() {
        let fixture = makeFixture()
        fixture.tracker.startSession()
        fixture.tracker.didReceiveWillEnterForeground(notification: .init(name: .init("test")))

        XCTAssertEqual(trackedNames(fixture), ["session_started", "session_started"])
    }

    func testBackgroundEndsTheSessionWithADurationBucketAndFlushes() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFixture(now: { now })

        fixture.tracker.startSession()
        now = now.addingTimeInterval(42)
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))

        XCTAssertEqual(trackedNames(fixture), ["session_started", "session_ended"])
        XCTAssertEqual(fixture.flushReasons, [.background])

        let captor = ArgumentCaptor<AnalyticsEvent>()
        verify(fixture.analytics, atLeastOnce()).track(captor.capture())
        XCTAssertEqual(
            captor.allValues.last?.properties[.durationBucket],
            .enumerated(DurationBucket.from30sTo60s.rawValue)
        )
    }

    func testBackgroundWithoutAStartEmitsNothing() {
        let fixture = makeFixture()
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))

        verify(fixture.analytics, never()).track(any())
        XCTAssertTrue(fixture.flushReasons.isEmpty)
    }

    func testBackgroundWorkIsBracketedByABackgroundTask() {
        let fixture = makeFixture()
        fixture.tracker.startSession()
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))

        XCTAssertEqual(fixture.runner.beganCount, 1)
        XCTAssertEqual(fixture.runner.endedCount, 1)
    }

    func testConsecutiveBackgroundsEmitOnlyOneEnd() {
        let fixture = makeFixture()
        fixture.tracker.startSession()
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))
        fixture.tracker.didReceiveDidEnterBackground(notification: .init(name: .init("test")))

        XCTAssertEqual(trackedNames(fixture), ["session_started", "session_ended"])
    }
}
