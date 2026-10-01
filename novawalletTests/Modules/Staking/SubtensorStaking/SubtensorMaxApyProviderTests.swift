import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorMaxApyProviderTests: XCTestCase {
    private typealias AlphaPage = BittensorApiResult<BittensorApi.AlphaYieldCollection>
    private typealias RootPage = BittensorApiResult<BittensorApi.RootYieldCollection>

    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let clock: TimeInterval = 1000
    private let cachedAt: TimeInterval = 500
    private let fetchedAt: TimeInterval = 1500
    private let rootPairHotkey = Data(repeating: 0x33, count: 32)
    private let unavailablePairHotkey = Data(repeating: 0x44, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)
    private let chutesUnrecommendedHotkey = Data(repeating: 0x66, count: 32)
    private let apexPairHotkey = Data(repeating: 0x77, count: 32)

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
            apiOperationFactory: apiOperationFactory,
            resolution: SubtensorMaxApyResolution(),
            operationQueue: OperationQueue(),
            requestSpacing: 0
        )

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.257788"))
    }

    func testMaxApySkipsStaleRatesUnrecommendedValidatorsAndUnavailableSubnets() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        try stubYields(
            apiOperationFactory,
            rootPage: makeRootPage(rate: "30", freshness: .stale),
            alphaPages: [
                64: [1: makeAlphaPage(
                    netuid: 64,
                    rows: [(chutesPairHotkey, "12.5"), (chutesUnrecommendedHotkey, "40")],
                    nextPage: nil,
                    receivedAt: cachedAt
                )]
            ]
        )

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [
                makePair(rootPairHotkey, netuid: SubtensorStakingPallet.rootNetuid),
                makePair(unavailablePairHotkey, netuid: 8),
                makePair(chutesPairHotkey, netuid: 64)
            ]),
            apiOperationFactory: apiOperationFactory
        )

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.125"))
    }

    func testSubnetPagingStopsOnceTheRecommendedValidatorIsFound() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        try stubYields(apiOperationFactory, alphaPages: [
            64: [
                1: makeAlphaPage(netuid: 64, rows: [(chutesUnrecommendedHotkey, "40")], nextPage: 2, receivedAt: cachedAt),
                2: makeAlphaPage(netuid: 64, rows: [(chutesPairHotkey, "12.5")], nextPage: 3, receivedAt: cachedAt),
                3: makeAlphaPage(netuid: 64, rows: [(apexPairHotkey, "60")], nextPage: nil, receivedAt: cachedAt)
            ]
        ])

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [makePair(chutesPairHotkey, netuid: 64)]),
            apiOperationFactory: apiOperationFactory
        )

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.125"))
        verify(apiOperationFactory, times(1)).createAlphaYieldWrapper(netuid: equal(to: 64), page: equal(to: 2))
        verify(apiOperationFactory, never()).createAlphaYieldWrapper(netuid: equal(to: 64), page: equal(to: 3))
    }

    func testNetworkFetchedPageDefersTheNextRequestBySpacing() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()
        let firstSubnetRequested = expectation(description: "first subnet requested")
        let secondSubnetRequested = expectation(description: "second subnet requested")
        secondSubnetRequested.isInverted = true

        let apexPage = try makeAlphaPage(netuid: 4, rows: [(apexPairHotkey, "20")], nextPage: nil, receivedAt: fetchedAt)
        let chutesPage = try makeAlphaPage(netuid: 64, rows: [(chutesPairHotkey, "12.5")], nextPage: nil, receivedAt: fetchedAt)

        stub(apiOperationFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: any(), page: any())).then { netuid, _ in
                guard netuid == 4 else {
                    secondSubnetRequested.fulfill()

                    return CompoundOperationWrapper.createWithResult(chutesPage)
                }

                firstSubnetRequested.fulfill()

                return CompoundOperationWrapper.createWithResult(apexPage)
            }
        }

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [
                makePair(apexPairHotkey, netuid: 4),
                makePair(chutesPairHotkey, netuid: 64)
            ]),
            apiOperationFactory: apiOperationFactory,
            requestSpacing: 60
        )

        let wrapper = provider.createMaxApyWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [firstSubnetRequested], timeout: 10)
        wait(for: [secondSubnetRequested], timeout: 1)

        wrapper.cancel()
    }

    func testPagesServedFromTheCacheAreNotSpaced() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        try stubYields(apiOperationFactory, alphaPages: [
            4: [1: makeAlphaPage(netuid: 4, rows: [(apexPairHotkey, "20")], nextPage: nil, receivedAt: cachedAt)],
            64: [1: makeAlphaPage(netuid: 64, rows: [(chutesPairHotkey, "12.5")], nextPage: nil, receivedAt: cachedAt)]
        ])

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [
                makePair(apexPairHotkey, netuid: 4),
                makePair(chutesPairHotkey, netuid: 64)
            ]),
            apiOperationFactory: apiOperationFactory,
            requestSpacing: 60
        )

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.2"))
    }

    func testWalkFailsWithoutMemoisingWhenASubnetStaysRateLimited() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()
        let rateLimitedRequests = SubtensorMaxApyWalk.retryLimit + 1

        let apexPage = try makeAlphaPage(netuid: 4, rows: [(apexPairHotkey, "20")], nextPage: nil, receivedAt: cachedAt)
        let chutesPage = try makeAlphaPage(netuid: 64, rows: [(chutesPairHotkey, "40")], nextPage: nil, receivedAt: cachedAt)

        stub(apiOperationFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: equal(to: 4), page: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(apexPage)
            }

            let chutesStub = when(stub.createAlphaYieldWrapper(netuid: equal(to: 64), page: any()))

            for _ in 0 ..< rateLimitedRequests {
                chutesStub.then { _, _ in
                    CompoundOperationWrapper.createWithError(BittensorApiError.rateLimited(requestId: nil))
                }
            }

            chutesStub.then { _, _ in
                CompoundOperationWrapper.createWithResult(chutesPage)
            }
        }

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [
                makePair(apexPairHotkey, netuid: 4),
                makePair(chutesPairHotkey, netuid: 64)
            ]),
            apiOperationFactory: apiOperationFactory
        )

        XCTAssertThrowsError(try run(provider.createMaxApyWrapper()))
        verify(apiOperationFactory, times(rateLimitedRequests))
            .createAlphaYieldWrapper(netuid: equal(to: 64), page: equal(to: 1))

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.4"))
    }

    func testRateLimitedSubnetIsRetriedOnlyAfterTheRetryDelay() {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()
        let subnetRequested = expectation(description: "subnet requested")
        subnetRequested.assertForOverFulfill = false
        let subnetRetried = expectation(description: "subnet retried")
        subnetRetried.expectedFulfillmentCount = 2
        subnetRetried.assertForOverFulfill = false
        subnetRetried.isInverted = true

        stub(apiOperationFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: any(), page: any())).then { _, _ in
                subnetRequested.fulfill()
                subnetRetried.fulfill()

                return CompoundOperationWrapper.createWithError(BittensorApiError.rateLimited(requestId: nil))
            }
        }

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [makePair(chutesPairHotkey, netuid: 64)]),
            apiOperationFactory: apiOperationFactory,
            retryDelay: 60
        )

        let wrapper = provider.createMaxApyWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [subnetRequested], timeout: 10)
        wait(for: [subnetRetried], timeout: 1)

        wrapper.cancel()
    }

    func testYieldPageServedFromTheExpiredCacheIsRetriedForAFreshRate() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        let expiredPage = try makeAlphaPage(
            netuid: 64,
            rows: [(chutesPairHotkey, "40")],
            nextPage: nil,
            receivedAt: cachedAt,
            isFromExpiredCache: true
        )

        let freshPage = try makeAlphaPage(
            netuid: 64,
            rows: [(chutesPairHotkey, "12.5")],
            nextPage: nil,
            receivedAt: cachedAt
        )

        stub(apiOperationFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: any(), page: any()))
                .then { _, _ in
                    CompoundOperationWrapper.createWithResult(expiredPage)
                }
                .then { _, _ in
                    CompoundOperationWrapper.createWithResult(freshPage)
                }
        }

        let provider = makeProvider(
            recommendationService: makeRecommendationService(pairs: [makePair(chutesPairHotkey, netuid: 64)]),
            apiOperationFactory: apiOperationFactory
        )

        XCTAssertEqual(try run(provider.createMaxApyWrapper()), Decimal(string: "0.125"))
    }

    func testProvidersSharingAResolutionReuseItsMaxApyForAnHour() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        try stubYields(apiOperationFactory, alphaPages: [
            64: [1: makeAlphaPage(netuid: 64, rows: [(chutesPairHotkey, "12.5")], nextPage: nil, receivedAt: cachedAt)]
        ])

        var memoClock: TimeInterval = 1000
        let resolution = SubtensorMaxApyResolution(timeProvider: { memoClock })
        let pairs = [makePair(chutesPairHotkey, netuid: 64)]
        let secondRecommendationService = makeRecommendationService(pairs: pairs)

        let first = makeProvider(
            recommendationService: makeRecommendationService(pairs: pairs),
            apiOperationFactory: apiOperationFactory,
            resolution: resolution
        )

        let second = makeProvider(
            recommendationService: secondRecommendationService,
            apiOperationFactory: apiOperationFactory,
            resolution: resolution
        )

        XCTAssertEqual(try run(first.createMaxApyWrapper()), Decimal(string: "0.125"))

        memoClock = 4599

        XCTAssertEqual(try run(second.createMaxApyWrapper()), Decimal(string: "0.125"))
        verify(secondRecommendationService, never()).createVerifiedRecommendationsWrapper()

        memoClock = 4600

        _ = try run(second.createMaxApyWrapper())

        verify(secondRecommendationService, times(1)).createVerifiedRecommendationsWrapper()
    }

    func testRequestMadeDuringAWalkJoinsItInsteadOfStartingAnother() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()
        let firstSubnetRequested = expectation(description: "first subnet requested")
        firstSubnetRequested.assertForOverFulfill = false
        let secondWalkStarted = expectation(description: "second walk started")
        secondWalkStarted.isInverted = true

        let apexPage = try makeAlphaPage(netuid: 4, rows: [(apexPairHotkey, "20")], nextPage: nil, receivedAt: fetchedAt)

        stub(apiOperationFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: any(), page: any())).then { _, _ in
                firstSubnetRequested.fulfill()

                return CompoundOperationWrapper.createWithResult(apexPage)
            }
        }

        let resolution = SubtensorMaxApyResolution()
        let pairs = [makePair(apexPairHotkey, netuid: 4), makePair(chutesPairHotkey, netuid: 64)]

        let first = makeProvider(
            recommendationService: makeRecommendationService(pairs: pairs),
            apiOperationFactory: apiOperationFactory,
            resolution: resolution,
            requestSpacing: 60
        )

        let second = makeProvider(
            recommendationService: makeRecommendationService(pairs: pairs) {
                secondWalkStarted.fulfill()
            },
            apiOperationFactory: apiOperationFactory,
            resolution: resolution,
            requestSpacing: 60
        )

        let firstWrapper = first.createMaxApyWrapper()
        OperationQueue().addOperations(firstWrapper.allOperations, waitUntilFinished: false)

        wait(for: [firstSubnetRequested], timeout: 10)

        let secondWrapper = second.createMaxApyWrapper()
        OperationQueue().addOperations(secondWrapper.allOperations, waitUntilFinished: false)

        wait(for: [secondWalkStarted], timeout: 1)

        firstWrapper.cancel()
        secondWrapper.cancel()
    }

    private func makeProvider(
        recommendationService: SubtensorRecommendationServiceProtocol,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        resolution: SubtensorMaxApyResolution = SubtensorMaxApyResolution(),
        requestSpacing: TimeInterval = 0,
        retryDelay: TimeInterval = 0
    ) -> SubtensorMaxApyProvider {
        let clock = clock

        return SubtensorMaxApyProvider(
            recommendationService: recommendationService,
            apiOperationFactory: apiOperationFactory,
            resolution: resolution,
            operationQueue: OperationQueue(),
            requestSpacing: requestSpacing,
            retryDelay: retryDelay,
            timeProvider: { clock }
        )
    }

    private func stubYields(
        _ apiOperationFactory: MockBittensorApiOperationFactoryProtocol,
        rootPage: RootPage? = nil,
        alphaPages: [UInt16: [Int: AlphaPage]]
    ) {
        stub(apiOperationFactory) { stub in
            when(stub.createRootYieldWrapper(page: any())).then { _ in
                guard let rootPage else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.routeNotPublished)
                }

                return CompoundOperationWrapper.createWithResult(rootPage)
            }

            when(stub.createAlphaYieldWrapper(netuid: any(), page: any())).then { netuid, page in
                guard let alphaPage = alphaPages[netuid]?[page] else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.datasetUnavailable(requestId: nil))
                }

                return CompoundOperationWrapper.createWithResult(alphaPage)
            }
        }
    }

    private func makeRecommendationService(
        pairs: [SubtensorRecommendedPair],
        onRequest: @escaping () -> Void = {}
    ) -> MockSubtensorRecommendationServiceProtocol {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()

        let recommendations = SubtensorVerifiedRecommendations(
            generation: SubtensorRecommendationGeneration(
                id: "8ebc85abd0bbeb6f282302ac48909c3d",
                sourceBlockNumber: 9_139_880,
                modelVersion: "5.0",
                ageSeconds: 420,
                receivedAt: cachedAt,
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
                onRequest()

                return CompoundOperationWrapper.createWithResult(recommendations)
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

    private func makeAlphaPage(
        netuid: UInt16,
        rows: [(hotkey: AccountId, rate: String)],
        nextPage: Int?,
        receivedAt: TimeInterval,
        isFromExpiredCache: Bool = false
    ) throws -> AlphaPage {
        let items = try rows.map { row in
            try BittensorApi.AlphaYield(
                metricKind: "ALPHA_VALIDATOR_APY",
                netuid: netuid,
                hotkey: row.hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
                validatorName: "validator",
                reportedRate: row.rate,
                reportedValidatorTrust: "0.9",
                reportedAlphaDividendsPerHotkey: "1",
                reportedAlphaStake: "1000",
                reportedNominatedStake: "10",
                sourceTimestamp: "2026-09-24T00:00:00Z"
            )
        }

        let collection = BittensorApi.AlphaYieldCollection(
            items: items,
            meta: BittensorApi.AlphaYieldCollection.Meta(
                completeness: .complete,
                components: BittensorApi.AlphaYieldCollection.Components(
                    alphaYield: makeComponent(freshness: .fresh, sourceClass: .primary)
                )
            ),
            pageInfo: BittensorApi.PageInfo(page: 1, pageSize: 100, total: 300, nextPage: nextPage)
        )

        return AlphaPage(
            value: collection,
            requestId: nil,
            receivedAt: receivedAt,
            isFromExpiredCache: isFromExpiredCache
        )
    }

    private func makeRootPage(rate: String, freshness: BittensorApi.Freshness) -> RootPage {
        let collection = BittensorApi.RootYieldCollection(
            items: [
                BittensorApi.RootYield(
                    metricKind: "ROOT_AGGREGATE_APY",
                    reportedRate: rate,
                    reportedRootEmission: "2952.118",
                    sourceTimestamp: "2026-09-24T00:00:00"
                )
            ],
            meta: BittensorApi.RootYieldCollection.Meta(
                completeness: .complete,
                components: BittensorApi.RootYieldCollection.Components(
                    rootYield: makeComponent(freshness: freshness, sourceClass: .legacy)
                )
            ),
            pageInfo: BittensorApi.PageInfo(page: 1, pageSize: 100, total: 1, nextPage: nil)
        )

        return RootPage(value: collection, requestId: nil, receivedAt: cachedAt, isFromExpiredCache: false)
    }

    private func makeComponent(
        freshness: BittensorApi.Freshness,
        sourceClass: BittensorApi.SourceClass
    ) -> BittensorApi.AvailableComponent {
        BittensorApi.AvailableComponent(
            asOf: asOf,
            freshness: freshness,
            valueQuality: .reported,
            sourceClass: sourceClass
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
