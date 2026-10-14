import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorValidatorPresetFactoryTests: XCTestCase {
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let existingHotkey = Data(repeating: 0x22, count: 32)
    private let rootPairHotkey = Data(repeating: 0x33, count: 32)
    private let targonPairHotkey = Data(repeating: 0x44, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)
    private let chutesRiskierPairHotkey = Data(repeating: 0x66, count: 32)

    func testExistingStakeValidatorIsPresetBeforeRecommendation() throws {
        let recommendationService = createRecommendationService()

        let preset = try run(
            createFactory(existingTake: Decimal(string: "0.09"), recommendationService: recommendationService)
                .createPresetWrapper(for: rootRef, existingHotkey: existingHotkey)
        )

        XCTAssertEqual(preset?.hotkey, existingHotkey)
        XCTAssertEqual(preset?.name, "Existing")
        verify(recommendationService, never()).createVerifiedRecommendationsWrapper()
    }

    func testSubnetPresetIsFirstRecommendedPairOfThatNetuid() throws {
        let preset = try run(
            createFactory(existingTake: nil, recommendationService: createRecommendationService())
                .createPresetWrapper(for: chutesRef, existingHotkey: nil)
        )

        XCTAssertEqual(preset?.hotkey, chutesPairHotkey)
        XCTAssertEqual(preset?.name, "Cinder Node")
    }

    func testNoPresetWhenRecommendationsAreStale() throws {
        let preset = try run(
            createFactory(existingTake: nil, recommendationService: createRecommendationService(freshness: .stale))
                .createPresetWrapper(for: chutesRef, existingHotkey: nil)
        )

        XCTAssertNil(preset)
    }

    private func generateItem(
        hotkey: AccountId,
        netuid: UInt16,
        name: String?,
        take: Decimal?
    ) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: name,
            take: take,
            reportedStake: nil,
            status: SubtensorValidatorChainStatus(uid: 1, hasPermit: true, blocksSinceUpdate: 10, isActive: true)
        )
    }

    private func createDirectoryService(existingTake: Decimal?) -> MockSubtensorValidatorDirectoryServiceProtocol {
        let directoryService = MockSubtensorValidatorDirectoryServiceProtocol()

        let names = [existingHotkey: "Existing", rootPairHotkey: "Blue Harbor", chutesPairHotkey: "Cinder Node"]

        stub(directoryService) { stub in
            when(stub.createDirectoryWrapper(for: any())).then { subnet in
                CompoundOperationWrapper.createWithResult(SubtensorValidatorDirectory(
                    subnet: subnet,
                    items: names.map { hotkey, name in
                        self.generateItem(hotkey: hotkey, netuid: subnet.netuid, name: name, take: Decimal(string: "0.09"))
                    },
                    listStamp: nil,
                    isPartial: false,
                    isEnrichmentTruncated: false,
                    chainBlock: 100
                ))
            }

            when(stub.createDetailWrapper(for: any(), subnet: any())).then { hotkey, subnet in
                let take = hotkey == self.existingHotkey ? existingTake : Decimal(string: "0.09")

                return CompoundOperationWrapper.createWithResult(SubtensorValidatorDetail(
                    item: self.generateItem(hotkey: hotkey, netuid: subnet.netuid, name: nil, take: take),
                    identity: nil
                ))
            }
        }

        return directoryService
    }

    private func generatePair(_ hotkey: AccountId, netuid: UInt16) -> SubtensorRecommendedPair {
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

    private func generateRecommendations(freshness: SubtensorBackendStamp.Freshness) -> SubtensorVerifiedRecommendations {
        SubtensorVerifiedRecommendations(
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
                stamp: SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: freshness),
                isPartial: false
            ),
            clientGates: SubtensorClientGates(
                maxTake: BigRational(numerator: 18, denominator: 100),
                requirePermit: true,
                requireActiveWithinCutoff: true
            ),
            topN: 3,
            classes: [
                .stable: [generatePair(rootPairHotkey, netuid: 0)],
                .balanced: [generatePair(targonPairHotkey, netuid: 4), generatePair(chutesPairHotkey, netuid: 64)],
                .higherUpside: [generatePair(chutesRiskierPairHotkey, netuid: 64)]
            ],
            droppedByGate: [:],
            verifiedAtBlock: 9_140_000
        )
    }

    private func createRecommendationService(
        freshness: SubtensorBackendStamp.Freshness = .fresh
    ) -> MockSubtensorRecommendationServiceProtocol {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()
        let recommendations = generateRecommendations(freshness: freshness)

        stub(recommendationService) { stub in
            when(stub.createClientGatesWrapper()).then {
                CompoundOperationWrapper.createWithResult(recommendations.clientGates)
            }

            when(stub.createVerifiedRecommendationsWrapper()).then {
                CompoundOperationWrapper.createWithResult(recommendations)
            }
        }

        return recommendationService
    }

    private func createFactory(
        existingTake: Decimal?,
        recommendationService: MockSubtensorRecommendationServiceProtocol
    ) -> SubtensorValidatorPresetFactory {
        SubtensorValidatorPresetFactory(
            directoryService: createDirectoryService(existingTake: existingTake),
            recommendationService: recommendationService,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
