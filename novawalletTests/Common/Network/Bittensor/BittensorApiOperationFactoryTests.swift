import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class BittensorApiOperationFactoryTests: XCTestCase {
    private let subnetsJson = """
    {"items":[{"additional":"","alphaOutstanding":"5120000","alphaReserve":"3410260.348230173","discord":"",\
    "githubRepo":"","name":"Chutes","netuid":64,"networkRegisteredAt":4531295,\
    "ownerColdkey":"5HAQXW8HcVSKCp6Se52dEePjsiFtkWqjTK9huLi1Hfa9DmTC",\
    "ownerHotkey":"5GBCaF2ekuV49ipSHxtntwHBNr8Lj3c2XYJtd8eacVwREVek","reportedRootProportion":"0.1311",\
    "subnetContact":"","subnetUrl":"","subnetWebsite":"","symbol":"ش","taoPerAlpha":"0.054961234",\
    "taoReserve":"187432.117","tempo":360}],"meta":{"completeness":"COMPLETE","components":{\
    "alphaPrices":{"asOf":"2026-09-24T09:29:30Z","availability":"AVAILABLE","freshness":"FRESH",\
    "sourceClass":"PRIMARY","valueQuality":"REPORTED"},\
    "subnetMetadata":{"asOf":"2026-09-24T09:25:00Z","availability":"AVAILABLE","freshness":"FRESH",\
    "sourceClass":"PRIMARY","valueQuality":"REPORTED"}}}}
    """

    private let generationMetaJson = """
    "clientGates":{"maxTake":"0.18","requireActiveWithinCutoff":true,"requirePermit":true},\
    "completeness":"COMPLETE","components":{"recommendations":{"asOf":"2026-09-24T09:23:00Z",\
    "availability":"AVAILABLE","freshness":"FRESH","sourceClass":"PRIMARY","valueQuality":"DERIVED"}},\
    "generation":{"ageSeconds":420,"carriedOverNetuids":[],"excludedNetuids":[],\
    "id":"8ebc85abd0bbeb6f282302ac48909c3d","inputFlags":[],"modelVersion":"5.0","servedFrom":"REDIS",\
    "sourceBlockNumber":9139880}
    """

    private var recommendationsJson: String {
        """
        {"classes":{"balanced":[],"higherUpside":[],"stable":[]},"meta":{\(generationMetaJson),\
        "counts":{"balanced":3,"excluded":212,"higherUpside":3,"stable":3},"topN":3}}
        """
    }

    private var rankedSubnetsJson: String {
        """
        {"items":[],"meta":{\(generationMetaJson),"policy":{"classification":"PAIR",\
        "insufficientHistory":"NEUTRAL","requireIdentity":true,"requirePositiveSignal":false}}}
        """
    }

    func testSubnetsDecodeFromTheFixture() throws {
        let transport = createTransport(replies: [createResponse(Data(subnetsJson.utf8), requestId: "req-subnets")])
        let factory = createFactory(transport: transport)

        let result = try run(factory.createSubnetsWrapper())

        XCTAssertEqual(result.value.items.count, 1)
        XCTAssertEqual(result.value.items.first { $0.netuid == 64 }?.taoPerAlpha, "0.054961234")
        XCTAssertEqual(result.requestId, "req-subnets")
        XCTAssertFalse(result.isFromExpiredCache)
    }

    func testGrammarInvalidDecimalIsAContractViolationWithTheRequestId() throws {
        let body = mutatedBody(
            recommendationsJson,
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
        let newer = Data(rankedSubnetsJson.utf8)
        let older = mutatedBody(
            rankedSubnetsJson,
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

        let admission = BittensorApiAdmission(
            scope: BittensorApiCacheScope(origin: "test", profile: 3, generation: 0, invalidationRevision: 0),
            endpoint: nil
        )

        stub(transport) { stub in
            when(stub.invalidationRevision.get).thenReturn(0)
            when(stub.addInvalidationObserver(any(), closure: any())).thenReturn(0)
            when(stub.createAdmissionWrapper()).then { CompoundOperationWrapper.createWithResult(admission) }
            when(stub.createResponseWrapper(for: any(), admission: any())).then { _ in
                CompoundOperationWrapper.createWithResult(remaining.removeFirst())
            }
        }

        return transport
    }

    private func createResponse(_ body: Data, requestId: String) -> BittensorApiRawResponse {
        BittensorApiRawResponse(statusCode: 200, requestId: requestId, body: body)
    }

    private func mutatedBody(_ original: String, replacing replacements: [(String, String)]) -> Data {
        var json = original

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
