import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorDiscoveryServiceTests: XCTestCase {
    private let rootHotkeyA = Data(repeating: 0x0A, count: 32)
    private let rootHotkeyB = Data(repeating: 0x0B, count: 32)
    private let subnetHotkeyC = Data(repeating: 0x0C, count: 32)
    private let subnetHotkeyD = Data(repeating: 0x0D, count: 32)
    private let preferredRootHotkey = Data(repeating: 0x0E, count: 32)
    private let generationId = "8ebc85abd0bbeb6f282302ac48909c3d"

    func testOffersNetTheSteadyRateOfTheFirstStableTakeAndFlagClassesWithoutCandidates() throws {
        let firstStableTake = takeFraction(9000)
        let netRate = try rate("0.0421", isNetOfTake: true)

        let mocks = Mocks()
        stubRecommendations(mocks, .success(makeRecommendations(
            stable: [pair(rootHotkeyA, 0, take: firstStableTake), pair(rootHotkeyB, 0, take: takeFraction(11796))],
            balanced: [pair(subnetHotkeyC, 64, take: takeFraction(1966))],
            higherUpside: []
        )))
        stubRootRate(mocks, rate: netRate)

        let offers = try run(makeService(mocks).createStrategyOffersWrapper())

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: netRate, isAvailable: true),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: true),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: false)
        ])

        verify(mocks.yieldService).createRootNetworkRateWrapper(take: equal(to: Optional(firstStableTake)))
        verify(mocks.yieldService, never()).createAlphaYieldsWrapper(for: any())
        verify(mocks.directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    func testOffersCarryTheGrossRootRateWhenTheRouteServesNoStablePair() throws {
        let grossRate = try rate("0.0513", isNetOfTake: false)

        let mocks = Mocks()
        stubRecommendations(mocks, .success(makeRecommendations(
            stable: [],
            balanced: [pair(subnetHotkeyC, 64, take: takeFraction(1966))],
            higherUpside: [pair(subnetHotkeyD, 19, take: takeFraction(1966))]
        )))
        stubRootRate(mocks, rate: grossRate)

        let offers = try run(makeService(mocks).createStrategyOffersWrapper())

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: grossRate, isAvailable: false),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: true),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: true)
        ])

        verify(mocks.yieldService).createRootNetworkRateWrapper(take: isNil())
        verify(mocks.directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    func testOffersKeepTheGrossChainRateWhenTheRecommendationsAreRateLimited() throws {
        let grossRate = try rate("0.0513", isNetOfTake: false)

        let mocks = Mocks()
        stubRecommendations(mocks, .failure(BittensorApiError.rateLimited(requestId: "request-3")))
        stubRootRate(mocks, rate: grossRate)

        let offers = try run(makeService(mocks).createStrategyOffersWrapper())

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: grossRate, isAvailable: false),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: false),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: false)
        ])

        verify(mocks.yieldService).createRootNetworkRateWrapper(take: isNil())
        verify(mocks.directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    func testOffersUseTheFallbackRootTakeWhenThePairRouteIsNotPublished() throws {
        let fallbackTake = takeFraction(5000)
        let netRate = try rate("0.0439", isNetOfTake: true)

        let mocks = Mocks()
        stubRecommendations(mocks, .failure(BittensorApiError.routeNotPublished))
        stubPreferredRoot(mocks, item: rootItem(preferredRootHotkey, take: fallbackTake))
        stubRootRate(mocks, rate: netRate)

        let offers = try run(makeService(mocks).createStrategyOffersWrapper())

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: netRate, isAvailable: true),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: false),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: false)
        ])

        verify(mocks.yieldService).createRootNetworkRateWrapper(take: equal(to: Optional(fallbackTake)))
    }

    func testCandidatesKeepServerOrderAndCarryTheGeneration() throws {
        let first = pair(subnetHotkeyD, 19, take: takeFraction(1966))
        let second = pair(subnetHotkeyC, 64, take: takeFraction(3000))

        let mocks = Mocks()
        stubRecommendations(mocks, .success(makeRecommendations(
            stable: [pair(rootHotkeyA, 0, take: takeFraction(9000))],
            balanced: [first, second],
            higherUpside: []
        )))

        let candidates = try run(makeService(mocks).createPickCandidatesWrapper(for: .balanced))

        XCTAssertEqual(candidates, SubtensorPickCandidates(
            kind: .balanced,
            candidates: [.pair(first), .pair(second)],
            generationId: generationId
        ))
    }

    func testSteadyFallsBackToTheGatedPreferredRootValidatorWhenTheDatasetIsUnavailable() throws {
        let preferred = rootItem(preferredRootHotkey, take: takeFraction(5000))

        let mocks = Mocks()
        stubRecommendations(mocks, .failure(BittensorApiError.datasetUnavailable(requestId: "request-1")))
        stubPreferredRoot(mocks, item: preferred)

        let candidates = try run(makeService(mocks).createPickCandidatesWrapper(for: .steady))

        XCTAssertEqual(candidates, SubtensorPickCandidates(
            kind: .steady,
            candidates: [.fallbackRoot(preferred)],
            generationId: nil
        ))

        verify(mocks.directoryService).createPreferredValidatorWrapper(
            for: equal(to: SubtensorSubnetRef(netuid: 0, registeredAt: 0))
        )
    }

    func testSteadyHasNoFallbackWhenTheRouteServesNoStablePair() throws {
        let mocks = Mocks()
        stubRecommendations(mocks, .success(makeRecommendations(
            stable: [],
            balanced: [pair(subnetHotkeyC, 64, take: takeFraction(1966))],
            higherUpside: []
        )))
        stubPreferredRoot(mocks, item: rootItem(preferredRootHotkey, take: takeFraction(5000)))

        let candidates = try run(makeService(mocks).createPickCandidatesWrapper(for: .steady))

        XCTAssertEqual(candidates, SubtensorPickCandidates(kind: .steady, candidates: [], generationId: generationId))
        verify(mocks.directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    func testRateLimitedRecommendationsFailWithoutFallback() {
        let mocks = Mocks()
        stubRecommendations(mocks, .failure(BittensorApiError.rateLimited(requestId: "request-2")))
        stubPreferredRoot(mocks, item: rootItem(preferredRootHotkey, take: takeFraction(5000)))

        XCTAssertThrowsError(try run(makeService(mocks).createPickCandidatesWrapper(for: .steady))) { error in
            guard case BittensorApiError.rateLimited = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }

        verify(mocks.directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    private struct Mocks {
        let yieldService = MockSubtensorYieldServiceProtocol()
        let directoryService = MockSubtensorValidatorDirectoryServiceProtocol()
        let recommendationService = MockSubtensorRecommendationServiceProtocol()
    }

    private func makeService(_ mocks: Mocks) -> SubtensorDiscoveryService {
        SubtensorDiscoveryService(
            yieldService: mocks.yieldService,
            directoryService: mocks.directoryService,
            recommendationService: mocks.recommendationService,
            operationQueue: OperationQueue()
        )
    }

    private func stubRecommendations(_ mocks: Mocks, _ result: Result<SubtensorVerifiedRecommendations, Error>) {
        stub(mocks.recommendationService) { stub in
            when(stub.createVerifiedRecommendationsWrapper()).then {
                switch result {
                case let .success(recommendations):
                    return CompoundOperationWrapper.createWithResult(recommendations)
                case let .failure(error):
                    return CompoundOperationWrapper.createWithError(error)
                }
            }
        }
    }

    private func stubPreferredRoot(_ mocks: Mocks, item: SubtensorValidatorDirectoryItem?) {
        stub(mocks.directoryService) { stub in
            when(stub.createPreferredValidatorWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(item)
            }
        }
    }

    private func stubRootRate(_ mocks: Mocks, rate: SubtensorRate?) {
        stub(mocks.yieldService) { stub in
            when(stub.createRootNetworkRateWrapper(take: any())).then { _ in
                CompoundOperationWrapper.createWithResult(rate)
            }
        }
    }

    private func makeRecommendations(
        stable: [SubtensorRecommendedPair],
        balanced: [SubtensorRecommendedPair],
        higherUpside: [SubtensorRecommendedPair]
    ) -> SubtensorVerifiedRecommendations {
        SubtensorVerifiedRecommendations(
            generation: SubtensorRecommendationGeneration(
                id: generationId,
                sourceBlockNumber: 9_139_880,
                modelVersion: "5.0",
                ageSeconds: 420,
                receivedAt: 0,
                isServedFromMemory: false,
                excludedNetuids: [],
                carriedOverNetuids: [],
                inputFlags: [],
                stamp: SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh),
                isPartial: false
            ),
            clientGates: .backendDefault,
            topN: 5,
            classes: [.stable: stable, .balanced: balanced, .higherUpside: higherUpside],
            droppedByGate: [:],
            verifiedAtBlock: 9_140_000
        )
    }

    private func pair(_ hotkey: AccountId, _ netuid: UInt16, take: Decimal) -> SubtensorRecommendedPair {
        let vtrust = SubtensorMetricScore(raw: 1, normalized: 1, weight: 1, isDerived: false, flags: [])

        return SubtensorRecommendedPair(
            netuid: netuid,
            hotkey: hotkey,
            subnetName: netuid == 0 ? "Root" : "subnet",
            symbol: netuid == 0 ? "Τ" : "α",
            validatorName: nil,
            score: 10,
            subnetRisk: nil,
            validatorRisk: 10,
            breakdown: SubtensorRecommendationBreakdown(
                volatility: nil,
                maxDrawdown: nil,
                poolDepth: nil,
                age: nil,
                emissionStability: nil,
                stakeConcentration: nil,
                permitMargin: nil,
                rootStakeMargin: nil,
                vtrust: vtrust
            ),
            effectiveStakeAlpha: 1000,
            rootStakeTao: 1000,
            priceTao: nil,
            flags: [],
            verification: SubtensorPairVerification(uid: 3, take: take, blocksSinceUpdate: nil)
        )
    }

    private func rootItem(_ hotkey: AccountId, take: Decimal) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: 0,
            name: nil,
            take: take,
            reportedStake: nil,
            status: SubtensorValidatorChainStatus(uid: 7, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil),
            isNovaPreferred: true
        )
    }

    private func rate(_ value: String, isNetOfTake: Bool) throws -> SubtensorRate {
        try SubtensorRate(
            annualRate: XCTUnwrap(Decimal(string: value)),
            source: .chainNetworkAverage(isNetOfTake: isNetOfTake)
        )
    }

    private func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
