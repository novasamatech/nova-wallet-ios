import XCTest
@testable import NovaAnalytics
import NovaAppAttest

final class AnalyticsUploadRequestTests: XCTestCase {
    private func makeFactory() -> AnalyticsUploadOperationFactory {
        AnalyticsUploadOperationFactory(baseURL: URL(string: "https://gateway.example/")!)
    }

    /// The proof is issued for the target, so the request has to follow the target and not the
    /// base URL it happened to be derived from.
    func testTheRequestFollowsTheTargetRatherThanTheBaseURL() throws {
        let target = try AttestationRequestTarget(
            url: URL(string: "https://elsewhere.example:8443/v1/other/path")!,
            method: "put",
            contentType: "text/plain"
        )

        let request = AnalyticsUploadOperationFactory.buildRequest(
            target: target,
            body: Data(),
            headers: nil
        )

        XCTAssertEqual(request.url?.absoluteString, "https://elsewhere.example:8443/v1/other/path")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "text/plain")
    }

    func testRequestCarriesTheBodyVerbatimAndTheThreeHeaders() throws {
        let factory = makeFactory()

        let body = Data(#"{"v":1,"events":[]}"#.utf8)
        let request = AnalyticsUploadOperationFactory.buildRequest(
            target: try factory.eventsTarget(),
            body: body,
            headers: [.clientId: "cid", .challenge: "chal", .signature: "sig"]
        )

        XCTAssertEqual(request.httpBody, body)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://gateway.example/v1/analytics/events")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client-Id"), "cid")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Challenge"), "chal")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signature"), "sig")
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    func testUnsignedRequestOmitsTheAttestationHeaders() throws {
        let factory = makeFactory()

        let request = AnalyticsUploadOperationFactory.buildRequest(
            target: try factory.eventsTarget(),
            body: Data("{}".utf8),
            headers: nil
        )

        XCTAssertNil(request.value(forHTTPHeaderField: "X-Signature"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Client-Id"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Challenge"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}
