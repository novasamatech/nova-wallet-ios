import XCTest
import NovaAuth
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsConsentRecoveryTests: XCTestCase {
    func testOnlyTwoAutomaticCooldownRearmsAreSharedAcrossDeliberateActions() throws {
        let harness = ConsentRecoveryHarness()
        harness.client.result = .failure(NovaAuthError.cooldown(retryAfter: 90))
        harness.enable()
        XCTAssertEqual(harness.scheduler.scheduled.map(\.delay), [90])
        harness.provider.publish(analyticsTestAuth(harness.client))
        harness.queue.drain()
        XCTAssertEqual(harness.client.contexts.count, 1)

        harness.client.result = .failure(NovaAuthError.cooldown(retryAfter: 0.1))
        harness.retry(0)
        XCTAssertEqual(harness.scheduler.scheduled.map(\.delay), [90, 2])
        harness.retry(1)
        XCTAssertEqual(harness.client.contexts.count, 3)
        XCTAssertEqual(harness.scheduler.scheduled.count, 2)

        harness.enabled.update { $0 = false }
        harness.recovery.cancel()
        harness.recovery.setActive(false)
        harness.recovery.setActive(true)
        harness.enabled.update { $0 = true }
        harness.enable()
        XCTAssertEqual(harness.client.contexts.count, 4)
        XCTAssertEqual(harness.scheduler.scheduled.count, 2)

        harness.client.result = .success(())
        for _ in 0 ..< 2 {
            harness.enabled.update { $0 = false }
            harness.recovery.cancel()
            harness.enabled.update { $0 = true }
            harness.enable()
        }
        XCTAssertEqual(harness.client.contexts.count, 6)
        XCTAssertEqual(harness.provider.requests, 6)
        XCTAssertEqual(harness.scheduler.scheduled.count, 2)
        let timer = try XCTUnwrap(harness.scheduler.scheduled.first)
        timer.action()
        harness.provider.publish(analyticsTestAuth(harness.client))
        harness.queue.drain()
        XCTAssertEqual(harness.client.contexts.count, 6)
    }

    func testFactoryAndChildCancellationCanReenterRecoveryAndSuppressLateResolution() {
        let harness = ConsentRecoveryHarness()
        let pending = ConsentRecoveryPendingResolution()
        let started = expectation(description: "resolution child started")
        let returned = expectation(description: "child cancellation returned after reentry")
        let reentries = Locked(0)
        pending.onStart = { started.fulfill() }
        pending.onCancel = { [weak recovery = harness.recovery] in
            recovery?.cancel()
            reentries.update { $0 += 1 }
        }
        harness.provider.createWrapper = { pending.createWrapper() }
        harness.provider.onCreate = { [weak recovery = harness.recovery] in recovery?.setActive(true) }

        DispatchQueue.global().async { harness.recovery.enableConsent() }
        guard XCTWaiter.wait(for: [started], timeout: 5) == .completed else {
            return XCTFail("Resolution child did not start")
        }
        DispatchQueue.global().async {
            harness.recovery.cancel()
            pending.resolve(analyticsTestAuth(harness.client))
            returned.fulfill()
        }
        guard XCTWaiter.wait(for: [returned], timeout: 5) == .completed else {
            return XCTFail("Child cancellation blocked while reentering recovery")
        }
        harness.queue.drain()

        XCTAssertTrue(pending.cancelled.value)
        XCTAssertEqual(reentries.value, 1)
        XCTAssertEqual(harness.provider.requests, 1)
        XCTAssertTrue(harness.client.contexts.isEmpty)
        XCTAssertTrue(harness.scheduler.scheduled.isEmpty)
    }

    func testTimerCancellationCanReenterRecoveryAndSuppressLateRetry() throws {
        let harness = ConsentRecoveryHarness()
        let returned = expectation(description: "timer cancellation returned after reentry")
        let reentries = Locked(0)
        harness.scheduler.onCancel = { [weak recovery = harness.recovery] in
            recovery?.cancel()
            reentries.update { $0 += 1 }
        }
        harness.client.result = .failure(NovaAuthError.cooldown(retryAfter: 1))
        harness.enable()
        let timer = try XCTUnwrap(harness.scheduler.scheduled.first)

        DispatchQueue.global().async {
            harness.recovery.setActive(false)
            timer.action()
            returned.fulfill()
        }
        guard XCTWaiter.wait(for: [returned], timeout: 5) == .completed else {
            return XCTFail("Timer cancellation blocked while reentering recovery")
        }
        harness.queue.drain()

        XCTAssertTrue(timer.cancelled.value)
        XCTAssertEqual(reentries.value, 1)
        XCTAssertEqual(harness.provider.requests, 1)
        XCTAssertEqual(harness.client.contexts.count, 1)
        XCTAssertEqual(harness.scheduler.scheduled.count, 1)
    }
}
