import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorValidatorPresetOperationFactoryTests: XCTestCase {
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorPallet.rootNetuid, registeredAt: 0)
    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let existingHotkey = Data(repeating: 0x22, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)
    private let topYieldHotkey = Data(repeating: 0x66, count: 32)
    private let secondYieldHotkey = Data(repeating: 0x77, count: 32)

    func testExistingStakeValidatorIsPresetBeforeRecommendation() throws {
        let recommendationOperationFactory = createRecommendationOperationFactory()

        let preset = try run(
            createFactory(
                existingTake: Decimal(string: "0.09"),
                recommendationOperationFactory: recommendationOperationFactory
            ).createPresetWrapper(for: rootRef, existingHotkey: existingHotkey)
        )

        XCTAssertEqual(preset?.hotkey, existingHotkey)
        XCTAssertEqual(preset?.name, "Existing")
        verify(recommendationOperationFactory, never()).createRecommendedValidatorsWrapper(for: any())
    }

    func testHighestYieldRecommendedValidatorBeatsEarlierLowerYieldOne() throws {
        let factory = createFactory(
            existingTake: nil,
            recommendationOperationFactory: createRecommendationOperationFactory(),
            yieldOperationFactory: createYieldOperationFactory(
                rates: [chutesPairHotkey: "12.5", topYieldHotkey: "31.2"]
            )
        )

        let preset = try withExtendedLifetime(factory) {
            try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: nil))
        }

        XCTAssertEqual(preset?.hotkey, topYieldHotkey)
        XCTAssertEqual(preset?.name, "Rizzo")
    }

    func testInactiveExistingStakeValidatorGivesWayToTheBestRecommendedOne() throws {
        let factory = createFactory(
            existingTake: nil,
            recommendationOperationFactory: createRecommendationOperationFactory(),
            yieldOperationFactory: createYieldOperationFactory(rates: [topYieldHotkey: "31.2"]),
            directoryOperationFactory: createDirectoryOperationFactory(existingTake: nil, inactiveDetails: [existingHotkey])
        )

        let preset = try withExtendedLifetime(factory) {
            try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: existingHotkey))
        }

        XCTAssertEqual(preset?.hotkey, topYieldHotkey)
    }

    func testOnlyTheNextBestYieldValidatorIsTriedWhenTheBestOneHasNoDetail() throws {
        let directoryOperationFactory = createDirectoryOperationFactory(
            existingTake: nil,
            failingDetails: [topYieldHotkey, secondYieldHotkey]
        )
        let factory = createFactory(
            existingTake: nil,
            recommendationOperationFactory: createRecommendationOperationFactory(),
            yieldOperationFactory: createYieldOperationFactory(
                rates: [chutesPairHotkey: "12.5", topYieldHotkey: "31.2", secondYieldHotkey: "20.4"]
            ),
            directoryOperationFactory: directoryOperationFactory
        )

        let preset = try withExtendedLifetime(factory) {
            try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: nil))
        }

        XCTAssertNil(preset)
        verify(directoryOperationFactory).createDetailWrapper(for: equal(to: secondYieldHotkey), subnet: any())
        verify(directoryOperationFactory, never()).createDetailWrapper(for: equal(to: chutesPairHotkey), subnet: any())
    }

    func testStaleRecommendationsAreRefetchedOnceThenFailThePreset() throws {
        let apiFactory = try createStaleApiFactory()
        let factory = createFactory(
            existingTake: nil,
            recommendationOperationFactory: SubtensorRecommendationOperationFactory(
                apiOperationFactory: apiFactory,
                chainOperationFactory: createChainFactory(),
                operationQueue: OperationQueue()
            )
        )

        try withExtendedLifetime(factory) {
            XCTAssertThrowsError(try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: nil))) {
                guard case BittensorApiError.generationStale = $0 else {
                    return XCTFail("Unexpected error \($0)")
                }
            }
        }

        verify(apiFactory, times(2)).createRankedValidatorsWrapper(netuid: any())
    }

    private func generateItem(
        hotkey: AccountId,
        netuid: UInt16,
        name: String?,
        take: Decimal?,
        isActive: Bool
    ) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: name,
            take: take,
            reportedStake: nil,
            status: SubtensorValidatorChainStatus(hasPermit: true, isActive: isActive)
        )
    }

    private func createDirectoryOperationFactory(
        existingTake: Decimal?,
        failingDetails: Set<AccountId> = [],
        inactiveDetails: Set<AccountId> = []
    ) -> MockSubtensorValidatorDirectoryOperationFactoryProtocol {
        let directoryOperationFactory = MockSubtensorValidatorDirectoryOperationFactoryProtocol()

        let names = [existingHotkey: "Existing", chutesPairHotkey: "Cinder Node"]

        stub(directoryOperationFactory) { stub in
            when(stub.createDetailWrapper(for: any(), subnet: any())).then { hotkey, subnet in
                guard !failingDetails.contains(hotkey) else {
                    return CompoundOperationWrapper.createWithError(
                        BittensorApiError.unavailable(code: nil, requestId: nil)
                    )
                }

                let take = hotkey == self.existingHotkey ? existingTake : Decimal(string: "0.09")

                return CompoundOperationWrapper.createWithResult(
                    self.generateItem(
                        hotkey: hotkey,
                        netuid: subnet.netuid,
                        name: names[hotkey],
                        take: take,
                        isActive: !inactiveDetails.contains(hotkey)
                    )
                )
            }
        }

        return directoryOperationFactory
    }

    private func createRecommendationOperationFactory() -> MockSubtensorRecommendationOperationFactoryProtocol {
        let recommendationOperationFactory = MockSubtensorRecommendationOperationFactoryProtocol()

        let recommended = SubtensorRecommendedValidators(
            validators: [
                SubtensorRecommendedValidator(hotkey: chutesPairHotkey, name: nil),
                SubtensorRecommendedValidator(hotkey: topYieldHotkey, name: "Rizzo"),
                SubtensorRecommendedValidator(hotkey: secondYieldHotkey, name: "Datura")
            ]
        )

        stub(recommendationOperationFactory) { stub in
            when(stub.createRecommendedValidatorsWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(recommended)
            }
        }

        return recommendationOperationFactory
    }

    private func createChainFactory() -> MockSubtensorValidatorChainOperationFactoryProtocol {
        let chainFactory = MockSubtensorValidatorChainOperationFactoryProtocol()

        stub(chainFactory) { stub in
            when(stub.createChainSnapshotWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithError(BittensorApiError.unavailable(code: nil, requestId: nil))
            }
        }

        return chainFactory
    }

    private func createStaleApiFactory() throws -> MockBittensorApiOperationFactoryProtocol {
        let collection = try BittensorApi.RankedValidatorCollection(
            meta: BittensorApi.RecommendationMetadata(
                components: BittensorApi.RecommendationMetadata.Components(
                    recommendations: BittensorApi.AvailableComponent(
                        asOf: Date(timeIntervalSince1970: 1_790_000_000),
                        freshness: .stale
                    )
                ),
                generation: BittensorApi.Generation(sourceBlockNumber: 9_139_880, carriedOverNetuids: []),
                clientGates: BittensorApi.ClientGates(maxTake: "0.18", requirePermit: true, requireActiveWithinCutoff: true)
            ),
            items: [
                BittensorApi.RankedValidator(
                    netuid: chutesRef.netuid,
                    hotkey: topYieldHotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
                    validatorName: "Rizzo",
                    recommendationClass: .balanced,
                    eligible: true,
                    clientChecks: [.uid, .validatorPermit, .take, .lastUpdate]
                )
            ]
        )

        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createRankedValidatorsWrapper(netuid: any())).then { _ in
                CompoundOperationWrapper.createWithResult(
                    BittensorApiResult(value: collection, requestId: nil, isFromExpiredCache: false)
                )
            }
        }

        return apiFactory
    }

    private func createYieldOperationFactory(
        rates: [AccountId: String]? = nil
    ) -> MockSubtensorYieldOperationFactoryProtocol {
        let yieldOperationFactory = MockSubtensorYieldOperationFactoryProtocol()
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        stub(yieldOperationFactory) { stub in
            when(stub.createAlphaYieldsWrapper(for: any())).then { netuid in
                guard let rates else {
                    return CompoundOperationWrapper.createWithError(
                        BittensorApiError.unavailable(code: nil, requestId: nil)
                    )
                }

                return CompoundOperationWrapper.createWithResult(
                    SubtensorAlphaYields(
                        netuid: netuid,
                        yields: rates.mapValues { SubtensorReportedYield(reportedRate: $0, stamp: stamp) },
                        stamp: stamp
                    )
                )
            }
        }

        return yieldOperationFactory
    }

    private func createFactory(
        existingTake: Decimal?,
        recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol,
        yieldOperationFactory: MockSubtensorYieldOperationFactoryProtocol? = nil,
        directoryOperationFactory: MockSubtensorValidatorDirectoryOperationFactoryProtocol? = nil
    ) -> SubtensorValidatorPresetOperationFactory {
        SubtensorValidatorPresetOperationFactory(
            directoryOperationFactory: directoryOperationFactory
                ?? createDirectoryOperationFactory(existingTake: existingTake),
            recommendationOperationFactory: recommendationOperationFactory,
            yieldOperationFactory: yieldOperationFactory ?? createYieldOperationFactory(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
