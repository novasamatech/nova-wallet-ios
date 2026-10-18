@testable import NovaAuth
import XCTest

final class NovaAuthHTTPTransportTests: XCTestCase {
    func testSwallowedCancellationCallbackFailsTheFlightSoTheNextDemandSendsAgain() throws {
        let harness = try AuthHarness()
        let http = NovaAuthHTTPTransport(protocolClasses: [CancelledLoadProtocol.self], watchdogTimeout: 0.2)
        let auth = harness.makeAuth(http: http)
        let context = try auth.activate(origin: harness.origin)
        assertError(.transport(.timedOut), auth.createAdmissionWrapper(in: context))
        harness.clock.advance(2)
        assertError(.transport(.timedOut), auth.createAdmissionWrapper(in: context))
    }
}

private final class CancelledLoadProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}
