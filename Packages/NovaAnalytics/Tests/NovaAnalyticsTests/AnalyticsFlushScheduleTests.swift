import XCTest
@testable import NovaAnalytics

final class AnalyticsFlushScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 0)
    private let anyFailure = AnalyticsTransportError.serverError(statusCode: 500)

    func testTheFirstFailureHoldsOffForAMinute() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(anyFailure, now: now)

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(60))
    }

    func testConsecutiveFailuresDoubleTheWindowUpToAnHour() {
        var schedule = AnalyticsFlushSchedule()

        let windows = (1 ... 8).map { _ -> TimeInterval in
            schedule.recordFailure(anyFailure, now: now)

            return schedule.nextFlushAllowedAt.timeIntervalSince(now)
        }

        XCTAssertEqual(windows, [60, 120, 240, 480, 960, 1920, 3600, 3600])
    }

    func testRetryAfterLengthensTheFirstWindowAndStillCountsTheFailure() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 120),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(120))
        XCTAssertEqual(schedule.failureCount, 1)
    }

    func testAShortRetryAfterCannotShortenAnAlreadyEscalatedWindow() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(anyFailure, now: now)
        schedule.recordFailure(anyFailure, now: now)
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 30),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(240))
    }

    func testADayLongRetryAfterIsHonouredInFull() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 503, retryAfter: 86400),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(86400))
        XCTAssertFalse(schedule.allows(reason: .interval, now: now))
        XCTAssertFalse(schedule.allows(reason: .interval, now: now.addingTimeInterval(86399)))
        XCTAssertTrue(schedule.allows(reason: .interval, now: now.addingTimeInterval(86400)))
    }

    func testARetryAfterBeyondADayIsClampedToADay() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 503, retryAfter: 2 * 86400),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(86400))
        XCTAssertFalse(schedule.allows(reason: .interval, now: now.addingTimeInterval(1)))
    }

    func testRetryLaterWithoutADelayFallsBackToTheExponentialWindow() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 503, retryAfter: nil),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(60))
        XCTAssertEqual(schedule.failureCount, 1)
    }

    func testASuccessClearsTheWindowAndTheFailureCount() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(anyFailure, now: now)
        schedule.recordFailure(anyFailure, now: now)

        schedule.recordSuccess()

        XCTAssertEqual(schedule.nextFlushAllowedAt, .distantPast)
        XCTAssertEqual(schedule.failureCount, 0)
    }

    func testLaunchAndManualFlushesIgnoreTheWindow() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(anyFailure, now: now)

        XCTAssertTrue(schedule.allows(reason: .launch, now: now))
        XCTAssertTrue(schedule.allows(reason: .manual, now: now))
        XCTAssertFalse(schedule.allows(reason: .threshold, now: now))
        XCTAssertFalse(schedule.allows(reason: .interval, now: now))
        XCTAssertFalse(schedule.allows(reason: .background, now: now))
    }

    func testTheThresholdNeedsFifteenSecondsSinceTheLastFlush() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)

        XCTAssertNil(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(14)))
        XCTAssertEqual(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(15)), .threshold)
    }

    func testAQueueBelowTheThresholdWaitsForTheInterval() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)

        XCTAssertNil(schedule.reason(forQueuedCount: 49, now: now.addingTimeInterval(299)))
        XCTAssertEqual(schedule.reason(forQueuedCount: 49, now: now.addingTimeInterval(300)), .interval)
    }

    func testAScheduleThatHasNeverFlushedFlushesOnTheFirstEvent() {
        let schedule = AnalyticsFlushSchedule()

        XCTAssertEqual(schedule.reason(forQueuedCount: 1, now: now), .interval)
    }

    func testAClockThatMovedBackwardsDoesNotWedgeTheWindow() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(anyFailure, now: now)

        let rewound = now.addingTimeInterval(-30 * 24 * 3600)

        XCTAssertTrue(schedule.allows(reason: .interval, now: rewound))
    }

    func testForgettingClearsBothTheLastFlushAndTheWindow() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)
        schedule.recordFailure(anyFailure, now: now)

        schedule.forget()

        XCTAssertEqual(schedule.lastFlushAt, .distantPast)
        XCTAssertEqual(schedule.nextFlushAllowedAt, .distantPast)
        XCTAssertEqual(schedule.failureCount, 0)
    }
}
