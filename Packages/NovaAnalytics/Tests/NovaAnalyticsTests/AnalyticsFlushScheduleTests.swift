import XCTest
@testable import NovaAnalytics

final class AnalyticsFlushScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 0)
    private let anyFailure = AnalyticsTransportError.serverError(statusCode: 500)

    func testBackoffDoublesUpToOneHour() {
        var schedule = AnalyticsFlushSchedule()

        let windows = (1 ... 8).map { _ -> TimeInterval in
            schedule.recordFailure(anyFailure, now: now)

            return schedule.nextFlushAllowedAt.timeIntervalSince(now)
        }

        XCTAssertEqual(windows, [60, 120, 240, 480, 960, 1920, 3600, 3600])
    }

    func testRetryAfterExtendsBackoff() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordFailure(
            AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 300),
            now: now
        )

        XCTAssertEqual(schedule.nextFlushAllowedAt, now.addingTimeInterval(300))
    }

    func testThresholdRequiresMinimumInterval() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)

        XCTAssertNil(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(14)))
        XCTAssertEqual(schedule.reason(forQueuedCount: 50, now: now.addingTimeInterval(15)), .threshold)
    }

    func testIntervalFlush() {
        var schedule = AnalyticsFlushSchedule()
        schedule.recordStart(at: now)

        XCTAssertNil(schedule.reason(forQueuedCount: 1, now: now.addingTimeInterval(299)))
        XCTAssertEqual(schedule.reason(forQueuedCount: 1, now: now.addingTimeInterval(300)), .interval)
    }
}
