import XCTest
@testable import novawallet

final class AnalyticsUploadRequestTests: XCTestCase {
    private func makeFactory() -> AnalyticsUploadOperationFactory {
        AnalyticsUploadOperationFactory(baseURL: URL(string: "https://gateway.example/")!)
    }

    func testRequestCarriesTheBodyVerbatimAndTheThreeHeaders() throws {
        let factory = makeFactory()

        let body = Data(#"{"v":1,"events":[]}"#.utf8)
        let request = try factory.buildRequest(
            body: body,
            headers: [.clientId: "cid", .challenge: "chal", .signature: "sig"]
        )

        // The signature covers these exact bytes — never a re-encode.
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

        // Mode .none in dev builds: the request goes out unsigned.
        let request = try factory.buildRequest(body: Data("{}".utf8), headers: nil)

        XCTAssertNil(request.value(forHTTPHeaderField: "X-Signature"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Client-Id"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Challenge"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}
