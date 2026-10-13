import XCTest
import NovaAuth
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsConsentRecoveryTests: XCTestCase {
    private let queue = ConsentRecoveryQueue()
    private let provider = OfflineAuthProvider()
    private let client = AnalyticsAuthClientSpy()
    private let enabled = Locked(true)

    func testOfflineOptInAdmitsOnceWhenTheEndpointIsAdopted() {
        let recovery = makeRecovery()
        recovery.enableConsent()
        queue.drain()
        XCTAssertTrue(client.admissions.isEmpty)
        provider.publish(analyticsTestAuth(client))
        queue.drain()
        provider.publish(analyticsTestAuth(client))
        queue.drain()
        XCTAssertEqual(client.admissions, [.userInitiated])
    }

    func testWithdrawalDiscardsTheParkedOptIn() {
        let recovery = makeRecovery()
        recovery.enableConsent()
        queue.drain()
        enabled.update { $0 = false }
        recovery.cancel()
        provider.publish(analyticsTestAuth(client))
        queue.drain()
        XCTAssertTrue(client.admissions.isEmpty)
    }

    private func makeRecovery() -> AnalyticsConsentAuthRecovery {
        let recovery = AnalyticsConsentAuthRecovery(
            provider: provider, operationQueue: queue, isConsentEnabled: { [enabled] in enabled.value }
        )
        recovery.setActive(true)
        return recovery
    }
}

private final class ConsentRecoveryQueue: OperationQueue, @unchecked Sendable {
    private let completions = DispatchGroup()

    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        for operation in ops {
            completions.enter()
            let completion = operation.completionBlock
            operation.completionBlock = { [completions] in
                completion?()
                completions.leave()
            }
        }
        super.addOperations(ops, waitUntilFinished: wait)
    }

    func drain() { XCTAssertEqual(completions.wait(timeout: .now() + 5), .success) }
}

private final class OfflineAuthProvider: AnalyticsAuthProvidingProtocol {
    private let availability = Locked(AnalyticsAuthAvailability())
    private var observer: ((AnalyticsAuthAvailability) -> Void)?

    var authAvailability: AnalyticsAuthAvailability { availability.value }

    func addAvailabilityObserver(
        _: AnyObject,
        closure: @escaping (AnalyticsAuthAvailability) -> Void
    ) -> AnalyticsAuthAvailability {
        observer = closure
        return availability.value
    }

    func publish(_ auth: AnalyticsAuth) {
        availability.update { $0 = AnalyticsAuthAvailability(revision: $0.revision + 1, invalidationRevision: 0, auth: auth) }
        observer?(availability.value)
    }

    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth> {
        .createWithError(URLError(.notConnectedToInternet))
    }
}
