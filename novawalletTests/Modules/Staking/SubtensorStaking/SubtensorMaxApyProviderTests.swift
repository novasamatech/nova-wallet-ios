import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorMaxApyProviderTests: XCTestCase {
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let rootPairHotkey = Data(repeating: 0x33, count: 32)
    private let unavailablePairHotkey = Data(repeating: 0x44, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)
    private let chutesUnrecommendedHotkey = Data(repeating: 0x66, count: 32)

    func testFixtureWorldMaxApyIsTheBestFreshRateAmongTheVerifiedRecommendedPairs() throws {
        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorApiFixtureTransport(),
            cache: BittensorApiResponseCache(operationQueue: OperationQueue(), logger: Logger.shared),
            logger: Logger.shared
        )

        let provider = SubtensorMaxApyProvider(
            recommendationService: SubtensorRecommendationService(
                apiOperationFactory: apiOperationFactory,
                chainOperationFactory: BittensorFixtureChainSnapshot(),
                operationQueue: OperationQueue()
            ),
            yieldService: SubtensorYieldService(apiOperationFactory: apiOperationFactory, operationQueue: OperationQueue()),
            operationQueue: OperationQueue()
        )

        let maxApy = try run(provider.createMaxApyWrapper())

        XCTAssertEqual(maxApy, Decimal(string: "0.257788"))
    }

    func testMaxApySkipsStaleRatesUnrecommendedValidatorsAndUnavailableSubnets() throws {
        let recommendationService = makeRecommendationService(
            pairs: [
                makePair(rootPairHotkey, netuid: SubtensorStakingPallet.rootNetuid),
                makePair(unavailablePairHotkey, netuid: 8),
                makePair(chutesPairHotkey, netuid: 64)
            ]
        )

        let provider = SubtensorMaxApyProvider(
            recommendationService: recommendationService,
            yieldService: makeYieldService(),
            operationQueue: OperationQueue()
        )

        let maxApy = try run(provider.createMaxApyWrapper())

        XCTAssertEqual(maxApy, Decimal(string: "0.125"))
    }

    func testResolvedMaxApyIsReusedUntilTheMemoLifetimeEnds() throws {
        let recommendationService = makeRecommendationService(pairs: [makePair(chutesPairHotkey, netuid: 64)])
        var now: TimeInterval = 1000

        let provider = SubtensorMaxApyProvider(
            recommendationService: recommendationService,
            yieldService: makeYieldService(),
            operationQueue: OperationQueue(),
            memoLifetime: 900,
            timeProvider: { now }
        )

        _ = try run(provider.createMaxApyWrapper())

        now = 1899

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.125"))
        verify(recommendationService, times(1)).createVerifiedRecommendationsWrapper()

        now = 1900

        _ = try run(provider.createMaxApyWrapper())

        verify(recommendationService, times(2)).createVerifiedRecommendationsWrapper()
    }

    private func makeYieldService() -> MockSubtensorYieldServiceProtocol {
        let yieldService = MockSubtensorYieldServiceProtocol()

        let rootYield = SubtensorReportedYield(
            reportedRate: "30",
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .stale)
        )

        let freshStamp = SubtensorBackendStamp(asOf: asOf, freshness: .fresh)

        let chutesYields = SubtensorAlphaYields(
            netuid: 64,
            yields: [
                chutesPairHotkey: SubtensorReportedYield(reportedRate: "12.5", stamp: freshStamp),
                chutesUnrecommendedHotkey: SubtensorReportedYield(reportedRate: "40", stamp: freshStamp)
            ],
            stamp: freshStamp,
            isTruncated: false
        )

        stub(yieldService) { stub in
            when(stub.createRootYieldWrapper()).thenReturn(CompoundOperationWrapper.createWithResult(rootYield))

            when(stub.createAlphaYieldsWrapper(for: any())).then { netuid in
                guard netuid == 64 else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.rateLimited(requestId: nil))
                }

                return CompoundOperationWrapper.createWithResult(chutesYields)
            }
        }

        return yieldService
    }

    private func makeRecommendationService(
        pairs: [SubtensorRecommendedPair]
    ) -> MockSubtensorRecommendationServiceProtocol {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()

        let recommendations = SubtensorVerifiedRecommendations(
            generation: SubtensorRecommendationGeneration(
                id: "8ebc85abd0bbeb6f282302ac48909c3d",
                sourceBlockNumber: 9_139_880,
                modelVersion: "5.0",
                ageSeconds: 420,
                receivedAt: 0,
                isServedFromMemory: false,
                excludedNetuids: [],
                carriedOverNetuids: [],
                inputFlags: [],
                stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
                isPartial: false
            ),
            clientGates: .backendDefault,
            topN: 3,
            classes: [
                .stable: pairs.filter { $0.netuid == SubtensorStakingPallet.rootNetuid },
                .balanced: pairs.filter { $0.netuid != SubtensorStakingPallet.rootNetuid }
            ],
            droppedByGate: [:],
            verifiedAtBlock: 9_140_000
        )

        stub(recommendationService) { stub in
            when(stub.createVerifiedRecommendationsWrapper()).then {
                CompoundOperationWrapper.createWithResult(recommendations)
            }
        }

        return recommendationService
    }

    private func makePair(_ hotkey: AccountId, netuid: UInt16) -> SubtensorRecommendedPair {
        SubtensorRecommendedPair(
            netuid: netuid,
            hotkey: hotkey,
            subnetName: "",
            symbol: "",
            validatorName: nil,
            score: 0,
            subnetRisk: nil,
            validatorRisk: 0,
            breakdown: SubtensorRecommendationBreakdown(
                volatility: nil,
                maxDrawdown: nil,
                poolDepth: nil,
                age: nil,
                emissionStability: nil,
                stakeConcentration: nil,
                permitMargin: nil,
                rootStakeMargin: nil,
                vtrust: SubtensorMetricScore(raw: nil, normalized: 0, weight: 0, isDerived: false, flags: [])
            ),
            effectiveStakeAlpha: 0,
            rootStakeTao: 0,
            priceTao: nil,
            flags: [],
            verification: SubtensorPairVerification(uid: 1, take: 0, blocksSinceUpdate: nil)
        )
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
