import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorRecommendationOperationFactoryTests: XCTestCase {
    private let head: BlockNumber = 9_140_000
    private let subnet = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let subnetKept = Data(repeating: 0x11, count: 32)
    private let subnetUnpermitted = Data(repeating: 0x12, count: 32)
    private let subnetSecondKept = Data(repeating: 0x13, count: 32)
    private let subnetTakeAboveMax = Data(repeating: 0x14, count: 32)
    private let subnetInactive = Data(repeating: 0x21, count: 32)
    private let listedOnly = Data(repeating: 0x31, count: 32)

    func testListVerificationReadsCandidateGatesAndListedTakesAtOneBlock() throws {
        let hotkeys = [subnetSecondKept, subnetUnpermitted, subnetKept, subnetInactive, subnetTakeAboveMax]
        let listed = [subnetKept, listedOnly]
        let apiFactory = try createApiFactory(hotkeys: hotkeys)
        let chainFactory = createChainFactory()

        let verification = try run(
            createOperationFactory(apiFactory, chainFactory).createListVerificationWrapper(for: subnet, listedHotkeys: listed)
        )

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory, times(1)).createChainSnapshotWrapper(for: captor.capture())
        XCTAssertEqual(captor.value?.pairs, hotkeys.map { pair($0, 64) })
        XCTAssertEqual(captor.value?.takeHotkeys, listed)
        XCTAssertEqual(try verification.recommended.get(), [subnetSecondKept, subnetKept])
        XCTAssertEqual(verification.takes[listedOnly], takeFraction(11796))
    }

    func testListVerificationStillReadsListedTakesWhenRecommendationsRouteFails() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRankedValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithError(BittensorApiError.unavailable(code: nil, requestId: nil))
            }
        }
        let chainFactory = createChainFactory()

        let verification = try run(
            createOperationFactory(apiFactory, chainFactory).createListVerificationWrapper(for: subnet, listedHotkeys: [listedOnly])
        )

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory, times(1)).createChainSnapshotWrapper(for: captor.capture())
        XCTAssertEqual(captor.value, SubtensorValidatorChainQuery(pairs: [], takeHotkeys: [listedOnly]))
        XCTAssertEqual(verification.takes[listedOnly], takeFraction(11796))
        XCTAssertThrowsError(try verification.recommended.get()) {
            guard case BittensorApiError.unavailable(code: nil, requestId: nil) = $0 else {
                return XCTFail("Unexpected error \($0)")
            }
        }
    }

    func testVerificationKeepsValidatorsPassingChainGatesAndDropsTheRest() throws {
        let hotkeys = [subnetSecondKept, subnetUnpermitted, subnetKept, subnetInactive, subnetTakeAboveMax]
        let apiFactory = try createApiFactory(hotkeys: hotkeys)
        let chainFactory = createChainFactory()

        let verified = try run(createOperationFactory(apiFactory, chainFactory).createRecommendedValidatorsWrapper(for: subnet))

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory).createChainSnapshotWrapper(for: captor.capture())
        XCTAssertEqual(captor.value?.pairs, hotkeys.map { pair($0, 64) })
        XCTAssertEqual(verified.validators.map(\.hotkey), [subnetSecondKept, subnetKept])
    }

    func testVerificationFailsWithoutReadingChainWhenRecommendationsRouteFails() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRankedValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithError(BittensorApiError.unavailable(code: nil, requestId: nil))
            }
        }
        let chainFactory = createChainFactory()
        let operationFactory = createOperationFactory(apiFactory, chainFactory)

        XCTAssertThrowsError(try run(operationFactory.createRecommendedValidatorsWrapper(for: subnet))) {
            guard case BittensorApiError.unavailable(code: nil, requestId: nil) = $0 else {
                return XCTFail("Unexpected error \($0)")
            }
        }
        verify(chainFactory, never()).createChainSnapshotWrapper(for: any())
    }

    private func createOperationFactory(
        _ apiFactory: BittensorApiOperationFactoryProtocol,
        _ chainFactory: SubtensorValidatorChainOperationFactoryProtocol
    ) -> SubtensorRecommendationOperationFactory {
        SubtensorRecommendationOperationFactory(
            apiOperationFactory: apiFactory,
            chainOperationFactory: chainFactory,
            operationQueue: OperationQueue()
        )
    }

    private func createApiFactory(hotkeys: [AccountId]) throws -> MockBittensorApiOperationFactoryProtocol {
        let component = BittensorApi.AvailableComponent(
            asOf: Date(timeIntervalSince1970: 1_790_000_000),
            freshness: .fresh
        )

        let generation = BittensorApi.Generation(sourceBlockNumber: 9_139_880, carriedOverNetuids: [])

        let gates = BittensorApi.ClientGates(maxTake: "0.18", requirePermit: true, requireActiveWithinCutoff: true)

        let collection = try BittensorApi.RankedValidatorCollection(
            meta: BittensorApi.RecommendationMetadata(
                components: BittensorApi.RecommendationMetadata.Components(recommendations: component),
                generation: generation,
                clientGates: gates
            ),
            items: hotkeys.map(rankedValidator)
        )

        let result = BittensorApiResult(value: collection, requestId: "request-1", isFromExpiredCache: false)
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRankedValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithResult(result)
            }
        }

        return apiFactory
    }

    private func createChainFactory() -> MockSubtensorValidatorChainOperationFactoryProtocol {
        var permits = [Bool](repeating: true, count: 32)
        permits[11] = false

        var lastUpdates = [UInt64](repeating: UInt64(head) - 10, count: 32)
        lastUpdates[20] = UInt64(head) - 6000

        let snapshot = SubtensorValidatorChainSnapshot(
            blockNumber: head,
            uids: [pair(subnetKept, 64): 10, pair(subnetUnpermitted, 64): 11, pair(subnetSecondKept, 64): 12,
                   pair(subnetTakeAboveMax, 64): 13, pair(subnetInactive, 64): 20],
            permits: [64: permits],
            lastUpdates: [64: lastUpdates],
            effectiveActivityCutoffs: [64: 5000],
            takes: [subnetKept: 6553, subnetUnpermitted: 0, subnetSecondKept: 11796,
                    subnetTakeAboveMax: 11797, subnetInactive: 0, listedOnly: 11796]
        )

        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()
        stub(chainFactory) { stub in
            when(stub.createChainSnapshotWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(snapshot)
            }
        }

        return chainFactory
    }

    private func rankedValidator(_ hotkey: AccountId) throws -> BittensorApi.RankedValidator {
        try BittensorApi.RankedValidator(
            netuid: 64,
            hotkey: hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
            validatorName: nil,
            recommendationClass: .balanced,
            eligible: true,
            clientChecks: [.uid, .validatorPermit, .take, .lastUpdate]
        )
    }

    private func pair(_ hotkey: AccountId, _ netuid: UInt16) -> SubtensorHotkeySubnet {
        SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
    }

    private func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
