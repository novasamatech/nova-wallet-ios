import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorRecommendationServiceTests: XCTestCase {
    private typealias RecommendationsResult = BittensorApiResult<BittensorApi.RecommendationCollection>
    private typealias RankingsResult = BittensorApiResult<BittensorApi.SubnetRankingCollection>

    private let head: BlockNumber = 9_140_000
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let receivedAt: TimeInterval = 5000
    private let rootKept = Data(repeating: 0x01, count: 32)
    private let rootUnseated = Data(repeating: 0x02, count: 32)
    private let rootTakeAboveMax = Data(repeating: 0x03, count: 32)
    private let subnetKept = Data(repeating: 0x11, count: 32)
    private let subnetUnpermittedTakeAboveMax = Data(repeating: 0x12, count: 32)
    private let subnetSecondKept = Data(repeating: 0x13, count: 32)
    private let subnetInactive = Data(repeating: 0x21, count: 32)
    private let subnetThirdKept = Data(repeating: 0x22, count: 32)
    private let subnetUnpermittedInactive = Data(repeating: 0x23, count: 32)
    private let subnetTakeAboveMaxInactive = Data(repeating: 0x24, count: 32)

    func testVerificationDropsEachFailingPairAtItsFirstGateAndKeepsServerOrder() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        try stubRecommendations(apiFactory, result: makeRecommendations(
            stable: [
                recommendation(rootKept, netuid: 0),
                recommendation(rootUnseated, netuid: 0),
                recommendation(rootTakeAboveMax, netuid: 0)
            ],
            balanced: [
                recommendation(subnetSecondKept, netuid: 64, score: "12.5"),
                recommendation(subnetUnpermittedTakeAboveMax, netuid: 64),
                recommendation(subnetKept, netuid: 64)
            ],
            higherUpside: [
                recommendation(subnetInactive, netuid: 19),
                recommendation(subnetThirdKept, netuid: 19),
                recommendation(subnetUnpermittedInactive, netuid: 19),
                recommendation(subnetTakeAboveMaxInactive, netuid: 19)
            ]
        ))

        stubSnapshot(chainFactory, snapshot: makeSnapshot())

        let verified = try run(makeService(apiFactory: apiFactory, chainFactory: chainFactory)
            .createVerifiedRecommendationsWrapper())

        let captor = ArgumentCaptor<SubtensorValidatorChainQuery>()
        verify(chainFactory).createChainSnapshotWrapper(for: captor.capture())

        let queriedPairs = [
            pair(rootKept, 0), pair(rootUnseated, 0), pair(rootTakeAboveMax, 0),
            pair(subnetSecondKept, 64), pair(subnetUnpermittedTakeAboveMax, 64), pair(subnetKept, 64),
            pair(subnetInactive, 19), pair(subnetThirdKept, 19), pair(subnetUnpermittedInactive, 19),
            pair(subnetTakeAboveMaxInactive, 19)
        ]

        XCTAssertEqual(captor.value, SubtensorValidatorChainQuery(pairs: queriedPairs, includesHotkeyAlpha: false))

        XCTAssertEqual(
            verified.classes.mapValues { $0.map(\.hotkey) },
            [.stable: [rootKept], .balanced: [subnetSecondKept, subnetKept], .higherUpside: [subnetThirdKept]]
        )

        XCTAssertEqual(
            verified.classes[.stable]?.first?.verification,
            SubtensorPairVerification(uid: 3, take: takeFraction(11796), blocksSinceUpdate: nil)
        )

        XCTAssertEqual(verified.classes[.balanced]?.map(\.verification.uid), [12, 10])
        XCTAssertEqual(verified.classes[.higherUpside]?.first?.verification.blocksSinceUpdate, 10)

        XCTAssertEqual(
            verified.droppedByGate,
            [.noCurrentUid: 1, .noPermit: 2, .takeAboveMax: 2, .inactive: 1]
        )

        let expectedGeneration = SubtensorRecommendationGeneration(
            id: "8ebc85abd0bbeb6f282302ac48909c3d",
            sourceBlockNumber: 9_139_880,
            modelVersion: "5.0",
            ageSeconds: 420,
            receivedAt: receivedAt,
            isServedFromMemory: false,
            excludedNetuids: [7],
            carriedOverNetuids: [],
            inputFlags: [],
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
            isPartial: true
        )

        XCTAssertEqual(verified.generation, expectedGeneration)
        XCTAssertEqual(verified.topN, 3)
        XCTAssertEqual(verified.verifiedAtBlock, head)
    }

    func testVerificationAppliesTheClientGatesOfTheResponseAndRemembersThem() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        let responseGates = BittensorApi.ClientGates(
            maxTake: "0.05",
            requirePermit: false,
            requireActiveWithinCutoff: false
        )

        try stubRecommendations(apiFactory, result: makeRecommendations(
            stable: [],
            balanced: [
                recommendation(subnetUnpermittedInactive, netuid: 19),
                recommendation(subnetKept, netuid: 64)
            ],
            higherUpside: [],
            gates: responseGates
        ))

        stubSnapshot(chainFactory, snapshot: makeSnapshot())

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        XCTAssertNil(service.lastSeenClientGates())

        let verified = try run(service.createVerifiedRecommendationsWrapper())

        let expectedGates = SubtensorClientGates(
            maxTake: BigRational(numerator: 5, denominator: 100),
            requirePermit: false,
            requireActiveWithinCutoff: false
        )

        let expectedPair = try SubtensorRecommendedPair(
            netuid: 19,
            hotkey: subnetUnpermittedInactive,
            subnetName: "blockmachine",
            symbol: "t",
            validatorName: "Validator",
            score: XCTUnwrap(Decimal(string: "16.32")),
            subnetRisk: XCTUnwrap(Decimal(string: "22.5")),
            validatorRisk: XCTUnwrap(Decimal(string: "10.15")),
            breakdown: SubtensorRecommendationBreakdown(
                volatility: metricScore("0.41", "38.2"),
                maxDrawdown: nil,
                poolDepth: nil,
                age: nil,
                emissionStability: nil,
                stakeConcentration: nil,
                permitMargin: metricScore("0.0455", "11.92"),
                rootStakeMargin: nil,
                vtrust: metricScore("0.8712", "7.2")
            ),
            effectiveStakeAlpha: XCTUnwrap(Decimal(string: "88900.5")),
            rootStakeTao: 0,
            priceTao: XCTUnwrap(Decimal(string: "0.0213")),
            flags: ["inputs_carried_over"],
            verification: SubtensorPairVerification(uid: 22, take: takeFraction(1966), blocksSinceUpdate: 6000)
        )

        XCTAssertEqual(verified.clientGates, expectedGates)
        XCTAssertEqual(verified.classes[.balanced], [expectedPair])
        XCTAssertEqual(verified.droppedByGate, [.takeAboveMax: 1])
        XCTAssertEqual(service.lastSeenClientGates(), expectedGates)
    }

    func testVerifiedRecommendationsFailWhenThePairRouteFails() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createRecommendationsWrapper()).then {
                CompoundOperationWrapper.createWithError(BittensorApiError.routeNotPublished)
            }
        }

        stubSnapshot(chainFactory, snapshot: makeSnapshot())

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        XCTAssertThrowsError(try run(service.createVerifiedRecommendationsWrapper())) { error in
            guard case BittensorApiError.routeNotPublished = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }

        XCTAssertNil(service.lastSeenClientGates())
        verify(chainFactory, never()).createChainSnapshotWrapper(for: any())
    }

    func testGrammarInvalidScoreFailsAsContractViolationWithTheRequestId() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        try stubRecommendations(apiFactory, result: makeRecommendations(
            stable: [],
            balanced: [recommendation(subnetKept, netuid: 64, score: "1e2")],
            higherUpside: []
        ))

        stubSnapshot(chainFactory, snapshot: makeSnapshot())

        let service = makeService(apiFactory: apiFactory, chainFactory: chainFactory)

        XCTAssertThrowsError(try run(service.createVerifiedRecommendationsWrapper())) { error in
            guard case let BittensorApiError.contractViolation(detail, requestId) = error else {
                return XCTFail("Unexpected error \(error)")
            }

            XCTAssertEqual(detail, "GET /recommendations: invalid classes.balanced[0].score")
            XCTAssertEqual(requestId, "request-1")
        }
    }

    func testRankedSubnetsMapTheSubnetViewAndItsGeneration() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let rankings = makeRankings()

        stub(apiFactory) { stub in
            when(stub.createRankedSubnetsWrapper()).then {
                CompoundOperationWrapper.createWithResult(rankings)
            }
        }

        let service = makeService(
            apiFactory: apiFactory,
            chainFactory: MockSubtensorValidatorChainOperationFactoryProtocol()
        )

        let ranked = try run(service.createRankedSubnetsWrapper())

        let expected = try SubtensorRankedSubnets(
            generation: SubtensorRecommendationGeneration(
                id: "8ebc85abd0bbeb6f282302ac48909c3d",
                sourceBlockNumber: 9_139_880,
                modelVersion: "5.0",
                ageSeconds: 420,
                receivedAt: receivedAt,
                isServedFromMemory: true,
                excludedNetuids: [7],
                carriedOverNetuids: [12],
                inputFlags: ["stale_price_series"],
                stamp: SubtensorBackendStamp(asOf: asOf, freshness: .stale),
                isPartial: true
            ),
            policy: SubtensorRecommendationPolicy(
                classification: .subnet,
                requiresIdentity: true,
                requiresPositiveSignal: false,
                insufficientHistory: .exclude
            ),
            items: [
                SubtensorRankedSubnet(
                    netuid: 0,
                    subnetName: "Root",
                    symbol: "Τ",
                    status: .scored,
                    isEligible: true,
                    reasons: [],
                    riskClass: .stable,
                    subnetRisk: nil,
                    breakdown: nil,
                    taoIn: nil,
                    priceTao: nil,
                    ageBlocks: nil,
                    scoredValidators: 64,
                    eligibleValidators: 60,
                    flags: []
                ),
                SubtensorRankedSubnet(
                    netuid: 64,
                    subnetName: "Chutes",
                    symbol: "ش",
                    status: .scored,
                    isEligible: true,
                    reasons: [],
                    riskClass: .balanced,
                    subnetRisk: XCTUnwrap(Decimal(string: "31.25")),
                    breakdown: SubtensorSubnetBreakdown(
                        volatility: metricScore("0.41", "38.2"),
                        maxDrawdown: metricScore("0.27", "22.1"),
                        poolDepth: metricScore("182345.123456789", "4.5", isDerived: true),
                        age: metricScore("4608705", "0"),
                        emissionStability: metricScore(nil, "50", isDerived: true, flags: ["metric_input_unavailable"]),
                        stakeConcentration: metricScore("0.66", "71.4")
                    ),
                    taoIn: XCTUnwrap(Decimal(string: "182345.123456789")),
                    priceTao: XCTUnwrap(Decimal(string: "0.0213")),
                    ageBlocks: 4_608_705,
                    scoredValidators: 31,
                    eligibleValidators: 12,
                    flags: ["ohlc_short_history"]
                ),
                SubtensorRankedSubnet(
                    netuid: 120,
                    subnetName: "Affine",
                    symbol: "ⴷ",
                    status: .gated,
                    isEligible: false,
                    reasons: ["pool_below_min"],
                    riskClass: nil,
                    subnetRisk: nil,
                    breakdown: nil,
                    taoIn: XCTUnwrap(Decimal(string: "74.5")),
                    priceTao: XCTUnwrap(Decimal(string: "0.0009")),
                    ageBlocks: 3_390_656,
                    scoredValidators: 0,
                    eligibleValidators: 0,
                    flags: []
                )
            ]
        )

        let expectedGates = SubtensorClientGates(
            maxTake: BigRational(numerator: 1, denominator: 10),
            requirePermit: false,
            requireActiveWithinCutoff: true
        )

        XCTAssertEqual(ranked, expected)
        XCTAssertEqual(ranked.subnet(for: 64)?.riskClass, .balanced)
        XCTAssertNil(ranked.subnet(for: 99))
        XCTAssertEqual(service.lastSeenClientGates(), expectedGates)
    }

    func testShownAgeAddsTheTimeElapsedSinceReceiptToTheServerAge() {
        let generation = SubtensorRecommendationGeneration(
            id: "8ebc85abd0bbeb6f282302ac48909c3d",
            sourceBlockNumber: 9_139_880,
            modelVersion: "5.0",
            ageSeconds: 420,
            receivedAt: receivedAt,
            isServedFromMemory: false,
            excludedNetuids: [],
            carriedOverNetuids: [],
            inputFlags: [],
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
            isPartial: false
        )

        XCTAssertEqual(generation.shownAge(at: receivedAt + 3600 + 30), 4050)
    }

    private func makeService(
        apiFactory: MockBittensorApiOperationFactoryProtocol,
        chainFactory: MockSubtensorValidatorChainOperationFactoryProtocol
    ) -> SubtensorRecommendationService {
        SubtensorRecommendationService(
            apiOperationFactory: apiFactory,
            chainOperationFactory: chainFactory,
            operationQueue: OperationQueue()
        )
    }

    private func stubRecommendations(_ apiFactory: MockBittensorApiOperationFactoryProtocol, result: RecommendationsResult) {
        stub(apiFactory) { stub in
            when(stub.createRecommendationsWrapper()).then {
                CompoundOperationWrapper.createWithResult(result)
            }
        }
    }

    private func stubSnapshot(
        _ chainFactory: MockSubtensorValidatorChainOperationFactoryProtocol,
        snapshot: SubtensorValidatorChainSnapshot
    ) {
        stub(chainFactory) { stub in
            when(stub.createChainSnapshotWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(snapshot)
            }
        }
    }

    private func makeSnapshot() -> SubtensorValidatorChainSnapshot {
        let headBlock = UInt64(head)

        var subnetPermits = [Bool](repeating: true, count: 256)
        subnetPermits[11] = false
        subnetPermits[22] = false

        var subnetLastUpdates = [UInt64](repeating: headBlock - 10, count: 256)
        subnetLastUpdates[20] = headBlock - 6000
        subnetLastUpdates[22] = headBlock - 6000
        subnetLastUpdates[23] = headBlock - 6000

        return SubtensorValidatorChainSnapshot(
            blockHash: "0x01",
            blockNumber: head,
            uids: [
                pair(rootKept, 0): 3,
                pair(rootTakeAboveMax, 0): 8,
                pair(subnetKept, 64): 10,
                pair(subnetUnpermittedTakeAboveMax, 64): 11,
                pair(subnetSecondKept, 64): 12,
                pair(subnetInactive, 19): 20,
                pair(subnetThirdKept, 19): 21,
                pair(subnetUnpermittedInactive, 19): 22,
                pair(subnetTakeAboveMaxInactive, 19): 23
            ],
            permits: [
                0: [Bool](repeating: false, count: 64),
                19: subnetPermits,
                64: subnetPermits
            ],
            lastUpdates: [
                0: [UInt64](repeating: headBlock - 45540, count: 64),
                19: subnetLastUpdates,
                64: subnetLastUpdates
            ],
            effectiveActivityCutoffs: [0: 100, 19: 5000, 64: 5000],
            takes: [
                rootKept: 11796,
                rootUnseated: 0,
                rootTakeAboveMax: 11797,
                subnetKept: 6553,
                subnetUnpermittedTakeAboveMax: 11797,
                subnetSecondKept: 11796,
                subnetInactive: 0,
                subnetThirdKept: 3276,
                subnetUnpermittedInactive: 1966,
                subnetTakeAboveMaxInactive: 11797
            ],
            hotkeyAlpha: [:]
        )
    }

    private func makeRecommendations(
        stable: [BittensorApi.Recommendation],
        balanced: [BittensorApi.Recommendation],
        higherUpside: [BittensorApi.Recommendation],
        gates: BittensorApi.ClientGates = BittensorApi.ClientGates(
            maxTake: "0.18",
            requirePermit: true,
            requireActiveWithinCutoff: true
        )
    ) -> RecommendationsResult {
        let collection = BittensorApi.RecommendationCollection(
            meta: BittensorApi.RecommendationMetadata(
                completeness: .partial,
                components: BittensorApi.RecommendationMetadata.Components(recommendations: component(.fresh)),
                generation: generation(servedFrom: .redis),
                clientGates: gates,
                topN: 3,
                counts: BittensorApi.ClassCounts(
                    stable: UInt64(stable.count),
                    balanced: UInt64(balanced.count),
                    higherUpside: UInt64(higherUpside.count),
                    excluded: 212
                )
            ),
            classes: BittensorApi.RecommendationClasses(stable: stable, balanced: balanced, higherUpside: higherUpside)
        )

        return BittensorApiResult(value: collection, requestId: "request-1", receivedAt: receivedAt, isFromExpiredCache: false)
    }

    private func makeRankings() -> RankingsResult {
        let collection = BittensorApi.SubnetRankingCollection(
            meta: BittensorApi.ViewMetadata(
                completeness: .partial,
                components: BittensorApi.RecommendationMetadata.Components(recommendations: component(.stale)),
                generation: BittensorApi.Generation(
                    id: "8ebc85abd0bbeb6f282302ac48909c3d",
                    sourceBlockNumber: 9_139_880,
                    modelVersion: "5.0",
                    ageSeconds: 420,
                    servedFrom: .memory,
                    excludedNetuids: [7],
                    carriedOverNetuids: [12],
                    inputFlags: ["stale_price_series"]
                ),
                clientGates: BittensorApi.ClientGates(maxTake: "0.1", requirePermit: false, requireActiveWithinCutoff: true),
                policy: BittensorApi.Policy(
                    classification: .subnet,
                    requireIdentity: true,
                    requirePositiveSignal: false,
                    insufficientHistory: .exclude
                )
            ),
            items: [
                ranking(netuid: 0, name: "Root", symbol: "Τ", riskClass: .stable, validators: (64, 60)),
                BittensorApi.SubnetRanking(
                    netuid: 64,
                    subnetName: "Chutes",
                    symbol: "ش",
                    status: .scored,
                    eligible: true,
                    reasons: [],
                    riskClass: .balanced,
                    subnetRisk: "31.25",
                    breakdown: BittensorApi.SubnetBreakdown(
                        volatility: metric("0.41", "38.2"),
                        maxDrawdown: metric("0.27", "22.1"),
                        poolDepth: metric("182345.123456789", "4.5", source: .derived),
                        age: metric("4608705", "0"),
                        emissionStability: metric(nil, "50", source: .derived, flags: ["metric_input_unavailable"]),
                        stakeConcentration: metric("0.66", "71.4")
                    ),
                    taoIn: "182345.123456789",
                    priceTao: "0.0213",
                    ageBlocks: 4_608_705,
                    validators: BittensorApi.SubnetValidatorCounts(scored: 31, eligible: 12),
                    flags: ["ohlc_short_history"]
                ),
                BittensorApi.SubnetRanking(
                    netuid: 120,
                    subnetName: "Affine",
                    symbol: "ⴷ",
                    status: .gated,
                    eligible: false,
                    reasons: ["pool_below_min"],
                    riskClass: nil,
                    subnetRisk: nil,
                    breakdown: nil,
                    taoIn: "74.5",
                    priceTao: "0.0009",
                    ageBlocks: 3_390_656,
                    validators: BittensorApi.SubnetValidatorCounts(scored: 0, eligible: 0),
                    flags: []
                )
            ]
        )

        return BittensorApiResult(value: collection, requestId: "request-2", receivedAt: receivedAt, isFromExpiredCache: false)
    }

    private func ranking(
        netuid: UInt16,
        name: String,
        symbol: String,
        riskClass: BittensorApi.RankedClass,
        validators: (scored: UInt64, eligible: UInt64)
    ) -> BittensorApi.SubnetRanking {
        BittensorApi.SubnetRanking(
            netuid: netuid,
            subnetName: name,
            symbol: symbol,
            status: .scored,
            eligible: true,
            reasons: [],
            riskClass: riskClass,
            subnetRisk: nil,
            breakdown: nil,
            taoIn: nil,
            priceTao: nil,
            ageBlocks: nil,
            validators: BittensorApi.SubnetValidatorCounts(scored: validators.scored, eligible: validators.eligible),
            flags: []
        )
    }

    private func recommendation(
        _ hotkey: AccountId,
        netuid: UInt16,
        score: String = "16.32"
    ) throws -> BittensorApi.Recommendation {
        let isRoot = netuid == 0

        return try BittensorApi.Recommendation(
            netuid: netuid,
            subnetName: isRoot ? "Root" : "blockmachine",
            symbol: isRoot ? "Τ" : "t",
            uid: 200,
            hotkey: address(hotkey),
            coldkey: address(Data(repeating: 0xEE, count: 32)),
            validatorName: "Validator",
            score: score,
            subnetRisk: isRoot ? nil : "22.5",
            validatorRisk: "10.15",
            breakdown: BittensorApi.RecommendationBreakdown(
                volatility: isRoot ? nil : metric("0.41", "38.2"),
                maxDrawdown: nil,
                poolDepth: nil,
                age: nil,
                emissionStability: nil,
                stakeConcentration: nil,
                permitMargin: isRoot ? nil : metric("0.0455", "11.92"),
                rootStakeMargin: isRoot ? metric("0.1831", "7.36") : nil,
                vtrust: metric("0.8712", "7.2")
            ),
            effectiveStakeAlpha: "88900.5",
            rootStakeTao: isRoot ? "98000" : "0",
            vtrust: "0.8712",
            priceTao: isRoot ? nil : "0.0213",
            flags: ["inputs_carried_over"],
            clientChecks: [.uid, .validatorPermit, .take, .lastUpdate]
        )
    }

    private func metric(
        _ raw: String?,
        _ normalized: String,
        source: BittensorApi.ValueQuality = .reported,
        flags: [String] = []
    ) -> BittensorApi.MetricScore {
        BittensorApi.MetricScore(raw: raw, normalized: normalized, weight: "0.15", source: source, flags: flags)
    }

    private func metricScore(
        _ raw: String?,
        _ normalized: String,
        isDerived: Bool = false,
        flags: [String] = []
    ) -> SubtensorMetricScore {
        SubtensorMetricScore(
            raw: raw.flatMap { Decimal(string: $0) },
            normalized: Decimal(string: normalized) ?? 0,
            weight: Decimal(string: "0.15") ?? 0,
            isDerived: isDerived,
            flags: flags
        )
    }

    private func component(_ freshness: BittensorApi.Freshness) -> BittensorApi.AvailableComponent {
        BittensorApi.AvailableComponent(asOf: asOf, freshness: freshness, valueQuality: .derived, sourceClass: .primary)
    }

    private func generation(servedFrom: BittensorApi.ServedFrom) -> BittensorApi.Generation {
        BittensorApi.Generation(
            id: "8ebc85abd0bbeb6f282302ac48909c3d",
            sourceBlockNumber: 9_139_880,
            modelVersion: "5.0",
            ageSeconds: 420,
            servedFrom: servedFrom,
            excludedNetuids: [7],
            carriedOverNetuids: [],
            inputFlags: []
        )
    }

    private func address(_ accountId: AccountId) throws -> String {
        try accountId.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix))
    }

    private func pair(_ hotkey: AccountId, _ netuid: UInt16) -> SubtensorHotkeySubnet {
        SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
    }

    private func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(65535)
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
