import XCTest
@testable import NovaAnalytics
import NovaAuth
import Operation_iOS

final class AnalyticsUploadRequestTests: XCTestCase {
    func testUploadUsesEventsPathBackgroundIntentAndExactBody() throws {
        let client = AnalyticsAuthClientSpy()
        let body = Data(#"{"v":1,"events":[]}"#.utf8)
        let wrapper = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client)).createUploadWrapper(body: body, beforeSend: {})
        let finished = expectation(description: "upload finished")
        wrapper.targetOperation.completionBlock = { finished.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [finished], timeout: 5)
        try wrapper.targetOperation.extractNoCancellableResultData()
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.path, "/v1/analytics/events")
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.intent, .background)
        XCTAssertEqual(request.contentType, "application/json")
        XCTAssertEqual(request.body, body)
    }
}
