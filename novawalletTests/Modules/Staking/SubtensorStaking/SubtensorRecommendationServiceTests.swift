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

    func testMalformedMaxTakeFailsAsContractViolation() throws {
        let apiFactory = try createApiFactory(balanced: [pair(subnetKept, 64)], maxTake: "1e2")
        let service = createService(apiFactory, createChainFactory())

        XCTAssertThrowsError(try run(service.createVerifiedRecommendationsWrapper())) { error in
            guard case let BittensorApiError.contractViolation(detail, requestId) = error else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(detail, "GET /recommendations: invalid meta.clientGates.maxTake")
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
        maxTake: String = "0.18"
    ) throws -> MockBittensorApiOperationFactoryProtocol {
        let component = BittensorApi.AvailableComponent(
            asOf: Date(timeIntervalSince1970: 1_790_000_000),
            freshness: .fresh
        )

        let generation = BittensorApi.Generation(sourceBlockNumber: 9_139_880, carriedOverNetuids: [])

        let gates = BittensorApi.ClientGates(maxTake: maxTake, requirePermit: true, requireActiveWithinCutoff: true)

        let collection = try BittensorApi.RecommendationCollection(
            meta: BittensorApi.RecommendationMetadata(
                components: BittensorApi.RecommendationMetadata.Components(recommendations: component),
                generation: generation,
                clientGates: gates
            ),
            classes: BittensorApi.RecommendationClasses(
                stable: stable.map(recommendation),
                balanced: balanced.map(recommendation),
                higherUpside: higherUpside.map(recommendation)
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

    private func recommendation(_ pair: SubtensorHotkeySubnet) throws -> BittensorApi.Recommendation {
        try BittensorApi.Recommendation(
            netuid: pair.netuid,
            hotkey: pair.hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
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
