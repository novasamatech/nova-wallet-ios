import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthCacheAdmissionTests: LifecycleTestCase {
    func testFreshAndStaleNativeCacheCannotBypassOriginCooldown() throws {
        for fresh in [true, false] {
            let harness = try LifecycleHarness()
            let (_, context) = try harness.registered(withToken: true)
            let request = try harness.request(context: context)
            let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.makeURL(),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Cache-Control": fresh ? "public, max-age=3600" : "public, max-age=0"]
            ))
            cache.storeCachedResponse(
                CachedURLResponse(response: response, data: Data("cached-protected-body".utf8)),
                for: URLRequest(url: try request.makeURL())
            )
            let counter = LifecycleHTTPAdmissionCounter(transport: NovaAuthHTTPTransport(cache: cache))
            let auth = harness.makeAuth(http: counter)
            _ = try auth.activate(origin: harness.origin)
            let now = try harness.clock.now()
            auth.gate.novaAuthLocked { auth.originCooldown.fail(now: now, random: 0, retryAfter: 20) }
            try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            XCTAssertEqual(counter.creations, 0)
            assertError(.cooldown(retryAfter: 20), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
            XCTAssertEqual(counter.creations, 1)
            XCTAssertTrue(harness.bootstrap.tokens.isEmpty)
        }
    }
}

private final class LifecycleHTTPAdmissionCounter: NovaAuthHTTPProtocol {
    let transport: NovaAuthHTTPProtocol
    var creations = 0
    init(transport: NovaAuthHTTPProtocol) { self.transport = transport }
    func clearReadCache() { transport.clearReadCache() }
    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        creations += 1
        return transport.createResponseWrapper(for: request, kind: kind, beforeSend: beforeSend)
    }
}
