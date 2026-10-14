import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class BittensorApiOperationFactoryTests: XCTestCase {
    func testSubnetsDecodeFromTheFixture() throws {
        let factory = createFactory(transport: BittensorApiFixtureTransport())

        let result = try run(factory.createSubnetsWrapper())

        XCTAssertEqual(result.value.items.count, 10)
        XCTAssertEqual(result.value.items.first { $0.netuid == 64 }?.taoPerAlpha, "0.054961234")
        XCTAssertEqual(result.requestId, "fixture-1")
        XCTAssertFalse(result.isFromExpiredCache)
    }

    func testGrammarInvalidDecimalIsAContractViolationWithTheRequestId() throws {
        let body = try mutatedBody(
            BittensorApiFixtureDocuments.recommendations(),
            replacing: [(#""maxTake":"0.18""#, #""maxTake":".18""#)]
        )
        let transport = createTransport(replies: [createResponse(body, requestId: "req-decimal")])
        let factory = createFactory(transport: transport)

        XCTAssertThrowsError(try run(factory.createRecommendationsWrapper())) { error in
            guard case let .contractViolation(detail, requestId) = error as? BittensorApiError else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(requestId, "req-decimal")
            XCTAssertTrue(detail.contains("maxTake"))
        }
    }

    func testAnOlderGenerationIsRejectedAndKeepsTheNewerSeed() throws {
        let newer = try makeBody(BittensorApiFixtureDocuments.rankedSubnets())
        let older = try mutatedBody(
            BittensorApiFixtureDocuments.rankedSubnets(),
            replacing: [
                (#""asOf":"2026-09-24T09:23:00Z""#, #""asOf":"2026-09-24T08:23:00Z""#),
                (#""id":"8ebc85abd0bbeb6f282302ac48909c3d""#, #""id":"0123456789abcdef0123456789abcdef""#)
            ]
        )
        let transport = createTransport(replies: [
            createResponse(newer, requestId: "req-newer"),
            createResponse(older, requestId: "req-older")
        ])
        let factory = createFactory(transport: transport)
        _ = try run(factory.createRankedSubnetsWrapper())

        XCTAssertThrowsError(try run(factory.createRankedSubnetsWrapper())) { error in
            guard case .generationStale = error as? BittensorApiError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(factory.peekRankedSubnets().value?.requestId, "req-newer")
    }

    private func createFactory(transport: BittensorApiTransportProtocol) -> BittensorApiOperationFactory {
        BittensorApiOperationFactory(
            transport: transport,
            cache: BittensorApiResponseCache(operationQueue: OperationQueue()),
            logger: Logger.shared
        )
    }

    private func createTransport(replies: [BittensorApiRawResponse]) -> MockBittensorApiTransportProtocol {
        let transport = MockBittensorApiTransportProtocol()
        var remaining = replies

        stub(transport) { stub in
            when(stub.createResponseWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(remaining.removeFirst())
            }
        }

        return transport
    }

    private func createResponse(_ body: Data, requestId: String) -> BittensorApiRawResponse {
        BittensorApiRawResponse(
            statusCode: 200,
            requestId: requestId,
            body: body,
            cacheDirectives: HTTPCacheDirectives(cacheControl: "public, max-age=150, must-revalidate", age: nil)
        )
    }

    private func makeBody(_ document: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
    }

    private func mutatedBody(_ document: [String: Any], replacing replacements: [(String, String)]) throws -> Data {
        var json = String(decoding: try makeBody(document), as: UTF8.self)

        for (target, replacement) in replacements {
            XCTAssertTrue(json.contains(target))
            json = json.replacingOccurrences(of: target, with: replacement)
        }

        return Data(json.utf8)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
