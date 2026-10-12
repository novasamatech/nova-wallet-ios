import XCTest
@testable import NovaAnalytics
import NovaAuth
import Operation_iOS

final class AnalyticsUploadRequestTests: XCTestCase {
    private func run(_ wrapper: CompoundOperationWrapper<Void>) throws {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func testUsesExistingEventsPathAndBackgroundIntent() throws {
        let client = AnalyticsAuthClientSpy()
        let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))
        try run(factory.createUploadWrapper(body: Data("{}".utf8), beforeSend: {}))
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.path, "/v1/analytics/events")
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.intent, .background)
        XCTAssertEqual(request.contentType, "application/json")
    }

    func testIncludesExactImmutableBodyAcrossPermittedRecovery() throws {
        let client = AnalyticsAuthClientSpy()
        client.simulateRecovery = true
        let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))
        let body = Data(#"{"v":1,"events":[]}"#.utf8)
        try run(factory.createUploadWrapper(body: body, beforeSend: {}))
        XCTAssertEqual(client.requests.map(\.body), [body, body])
    }

    func testConsentIsRecheckedBeforeRecoverySend() {
        let client = AnalyticsAuthClientSpy()
        client.simulateRecovery = true
        let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))
        var checks = 0
        XCTAssertThrowsError(try run(factory.createUploadWrapper(body: Data("{}".utf8), beforeSend: {
            checks += 1
            if checks == 2 { throw AnalyticsUploadAbort.consentWithdrawn }
        })))
        XCTAssertEqual(checks, 2)
        XCTAssertEqual(client.requests.count, 1)
    }

    func testConsentRevokedDuringInitialAdmissionStopsFirstSend() {
        let client = AnalyticsAuthClientSpy()
        let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))
        XCTAssertThrowsError(try run(factory.createUploadWrapper(body: Data("{}".utf8), beforeSend: {
            throw AnalyticsUploadAbort.consentWithdrawn
        })))
        XCTAssertTrue(client.requests.isEmpty)
    }
}
