import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorRecommendationServiceTests: XCTestCase {
    private let head: BlockNumber = 9_140_000
    private let rootKept = Data(repeating: 0x01, count: 32)
    private let rootUnseated = Data(repeating: 0x02, count: 32)
    private let subnetKept = Data(repeating: 0x11, count: 32)
    private let subnetUnpermitted = Data(repeating: 0x12, count: 32)
    private let subnetSecondKept = Data(repeating: 0x13, count: 32)
    private let subnetTakeAboveMax = Data(repeating: 0x14, count: 32)
    private let subnetInactive = Data(repeating: 0x21, count: 32)

    func testVerificationKeepsPairsPassingChainGatesAndDropsTheRest() throws {
        let stable = [pair(rootKept, 0), pair(rootUnseated, 0)]
        let balanced = [pair(subnetSecondKept, 64), pair(subnetUnpermitted, 64), pair(subnetKept, 64)]
        let higherUpside = [pair(subnetInactive, 64), pair(subnetTakeAboveMax, 64)]
        let apiFactory = try createApiFactory(stable: stable, balanced: balanced, higherUpside: higherUpside)
        let chainFactory = createChainFactory()

        let verified = try run(createService(apiFactory, chainFactory).createVerifiedRecommendationsWrapper())

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory).createChainSnapshotWrapper(for: captor.capture())
        XCTAssertEqual(captor.value?.pairs, stable + balanced + higherUpside)
        XCTAssertEqual(
            verified.classes.mapValues { $0.map(\.hotkey) },
            [.stable: [rootKept], .balanced: [subnetSecondKept, subnetKept], .higherUpside: []]
        )
        XCTAssertEqual(
            verified.classes[.stable]?.first?.verification,
            SubtensorPairVerification(uid: 3, take: Decimal(11796) / Decimal(65535), blocksSinceUpdate: nil)
        )
        XCTAssertEqual(verified.classes[.balanced]?.map(\.verification.uid), [12, 10])
        XCTAssertEqual(verified.classes[.balanced]?.last?.verification.blocksSinceUpdate, 10)
        XCTAssertEqual(verified.droppedByGate, [.noCurrentUid: 1, .noPermit: 1, .takeAboveMax: 1, .inactive: 1])
        XCTAssertEqual(verified.verifiedAtBlock, head)
    }

    func testVerificationFailsWithoutReadingChainWhenRecommendationsRouteFails() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRecommendationsWrapper()).then {
                CompoundOperationWrapper.createWithError(BittensorApiError.routeNotPublished)
            }
        }
        let chainFactory = createChainFactory()

        XCTAssertThrowsError(try run(createService(apiFactory, chainFactory).createVerifiedRecommendationsWrapper())) {
            guard case BittensorApiError.routeNotPublished = $0 else {
                return XCTFail("Unexpected error \($0)")
            }
        }
        verify(chainFactory, never()).createChainSnapshotWrapper(for: any())
    }

    func testMalformedScoreFailsAsContractViolation() throws {
        let apiFactory = try createApiFactory(balanced: [pair(subnetKept, 64)], score: "1e2")
        let service = createService(apiFactory, createChainFactory())

        XCTAssertThrowsError(try run(service.createVerifiedRecommendationsWrapper())) { error in
            guard case let BittensorApiError.contractViolation(detail, requestId) = error else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(detail, "GET /recommendations: invalid classes.balanced[0].score")
            XCTAssertEqual(requestId, "request-1")
        }
    }

    private func createService(
        _ apiFactory: BittensorApiOperationFactoryProtocol,
        _ chainFactory: SubtensorValidatorChainOperationFactoryProtocol
    ) -> SubtensorRecommendationService {
        SubtensorRecommendationService(
            apiOperationFactory: apiFactory,
            chainOperationFactory: chainFactory,
            operationQueue: OperationQueue()
        )
    }

    private func createApiFactory(
        stable: [SubtensorHotkeySubnet] = [],
        balanced: [SubtensorHotkeySubnet] = [],
        higherUpside: [SubtensorHotkeySubnet] = [],
        score: String = "16.32"
    ) throws -> MockBittensorApiOperationFactoryProtocol {
        let component = BittensorApi.AvailableComponent(
            asOf: Date(timeIntervalSince1970: 1_790_000_000),
            freshness: .fresh, valueQuality: .derived, sourceClass: .primary
        )

        let generation = BittensorApi.Generation(
            id: "8ebc85abd0bbeb6f282302ac48909c3d", sourceBlockNumber: 9_139_880, modelVersion: "5.0", ageSeconds: 420,
            servedFrom: .redis, excludedNetuids: [7], carriedOverNetuids: [], inputFlags: []
        )

        let gates = BittensorApi.ClientGates(maxTake: "0.18", requirePermit: true, requireActiveWithinCutoff: true)

        let collection = try BittensorApi.RecommendationCollection(
            meta: BittensorApi.RecommendationMetadata(
                completeness: .partial,
                components: BittensorApi.RecommendationMetadata.Components(recommendations: component),
                generation: generation,
                clientGates: gates,
                topN: 3,
                counts: BittensorApi.ClassCounts(stable: 0, balanced: 0, higherUpside: 0, excluded: 212)
            ),
            classes: BittensorApi.RecommendationClasses(
                stable: stable.map { try recommendation($0, score: score) },
                balanced: balanced.map { try recommendation($0, score: score) },
                higherUpside: higherUpside.map { try recommendation($0, score: score) }
            )
        )

        let result = BittensorApiResult(
            value: collection, requestId: "request-1", receivedAt: 0, isFromExpiredCache: false
        )
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRecommendationsWrapper()).then { CompoundOperationWrapper.createWithResult(result) }
        }

        return apiFactory
    }

    private func createChainFactory() -> MockSubtensorValidatorChainOperationFactoryProtocol {
        var permits = [Bool](repeating: true, count: 32)
        permits[11] = false

        var lastUpdates = [UInt64](repeating: UInt64(head) - 10, count: 32)
        lastUpdates[20] = UInt64(head) - 6000

        let snapshot = SubtensorValidatorChainSnapshot(
            blockHash: "0x01",
            blockNumber: head,
            uids: [pair(rootKept, 0): 3, pair(subnetKept, 64): 10, pair(subnetUnpermitted, 64): 11,
                   pair(subnetSecondKept, 64): 12, pair(subnetTakeAboveMax, 64): 13, pair(subnetInactive, 64): 20],
            permits: [64: permits],
            lastUpdates: [64: lastUpdates],
            effectiveActivityCutoffs: [64: 5000],
            takes: [rootKept: 11796, subnetKept: 6553, subnetUnpermitted: 0, subnetSecondKept: 11796,
                    subnetTakeAboveMax: 11797, subnetInactive: 0],
            hotkeyAlpha: [:]
        )

        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()
        stub(chainFactory) { stub in
            when(stub.createChainSnapshotWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(snapshot)
            }
        }

        return chainFactory
    }

    private func recommendation(_ pair: SubtensorHotkeySubnet, score: String) throws -> BittensorApi.Recommendation {
        let vtrust = BittensorApi.MetricScore(
            raw: "0.8712", normalized: "7.2", weight: "0.15", source: .reported, flags: []
        )
        let format = ChainFormat.substrate(SubstrateConstants.genericAddressPrefix)

        return try BittensorApi.Recommendation(
            netuid: pair.netuid,
            subnetName: "blockmachine",
            symbol: "t",
            uid: 200,
            hotkey: pair.hotkey.toAddress(using: format),
            coldkey: Data(repeating: 0xEE, count: 32).toAddress(using: format),
            validatorName: "Validator",
            score: score,
            subnetRisk: nil,
            validatorRisk: "10.15",
            breakdown: BittensorApi.RecommendationBreakdown(
                volatility: nil, maxDrawdown: nil, poolDepth: nil, age: nil, emissionStability: nil,
                stakeConcentration: nil, permitMargin: nil, rootStakeMargin: nil, vtrust: vtrust
            ),
            effectiveStakeAlpha: "88900.5",
            rootStakeTao: "0",
            vtrust: "0.8712",
            priceTao: nil,
            flags: [],
            clientChecks: [.uid, .validatorPermit, .take, .lastUpdate]
        )
    }

    private func pair(_ hotkey: AccountId, _ netuid: UInt16) -> SubtensorHotkeySubnet {
        SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
