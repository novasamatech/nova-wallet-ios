import XCTest
@testable import NovaAnalytics

final class AnalyticsFlushScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 0)
    private let anyFailure = AnalyticsTransportError.serverError(statusCode: 500)

    func testConsecutiveFailuresDoubleTheWindowUpToAnHour() {
        var schedule = AnalyticsFlushSchedule()

        let windows = (1 ... 8).map { _ -> TimeInterval in
            schedule.recordFailure(anyFailure, now: now)

            return schedule.nextFlushAllowedAt.timeIntervalSince(now)
        }

        XCTAssertEqual(windows, [60, 120, 240, 480, 960, 1920, 3600, 3600])
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

    func testTheThresholdNeedsFifteenSecondsSinceTheLastFlush() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)

        XCTAssertNil(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(14)))
        XCTAssertEqual(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(15)), .threshold)
    }
}
