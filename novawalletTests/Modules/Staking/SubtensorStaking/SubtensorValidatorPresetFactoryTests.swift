import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorValidatorPresetFactoryTests: XCTestCase {
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let existingHotkey = Data(repeating: 0x22, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)
    private let topYieldHotkey = Data(repeating: 0x66, count: 32)
    private let secondYieldHotkey = Data(repeating: 0x77, count: 32)

    func testExistingStakeValidatorIsPresetBeforeRecommendation() throws {
        let recommendationService = createRecommendationService()

        let preset = try run(
            createFactory(existingTake: Decimal(string: "0.09"), recommendationService: recommendationService)
                .createPresetWrapper(for: rootRef, existingHotkey: existingHotkey)
        )

        XCTAssertEqual(preset?.hotkey, existingHotkey)
        XCTAssertEqual(preset?.name, "Existing")
        verify(recommendationService, never()).createRecommendedValidatorsWrapper(for: any())
    }

    func testHighestYieldRecommendedValidatorBeatsEarlierLowerYieldOne() throws {
        let factory = createFactory(
            existingTake: nil,
            recommendationService: createRecommendationService(),
            yieldService: createYieldService(rates: [chutesPairHotkey: "12.5", topYieldHotkey: "31.2"])
        )

        let preset = try withExtendedLifetime(factory) {
            try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: nil))
        }

        XCTAssertEqual(preset?.hotkey, topYieldHotkey)
        XCTAssertEqual(preset?.name, "Rizzo")
    }

    func testNextBestYieldValidatorIsPresetWhenTheBestOneHasNoDetail() throws {
        let factory = createFactory(
            existingTake: nil,
            recommendationService: createRecommendationService(),
            yieldService: createYieldService(
                rates: [chutesPairHotkey: "12.5", topYieldHotkey: "31.2", secondYieldHotkey: "20.4"]
            ),
            failingDetails: [topYieldHotkey]
        )

        let preset = try withExtendedLifetime(factory) {
            try run(factory.createPresetWrapper(for: chutesRef, existingHotkey: nil))
        }

        XCTAssertEqual(preset?.hotkey, secondYieldHotkey)
        XCTAssertEqual(preset?.name, "Datura")
    }

    func testStaleRecommendationsAreRefetchedOnceThenFailThePreset() throws {
        let apiFactory = try createStaleApiFactory()
        let factory = createFactory(
            existingTake: nil,
            recommendationService: SubtensorRecommendationService(
                apiOperationFactory: apiFactory,
                chainOperationFactory: MockSubtensorValidatorChainOperationFactoryProtocol(),
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
        take: Decimal?
    ) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: name,
            take: take,
            reportedStake: nil,
            status: SubtensorValidatorChainStatus(hasPermit: true, isActive: true)
        )
    }

    private func createDirectoryService(
        existingTake: Decimal?,
        failingDetails: Set<AccountId>
    ) -> MockSubtensorValidatorDirectoryServiceProtocol {
        let directoryService = MockSubtensorValidatorDirectoryServiceProtocol()

        let names = [existingHotkey: "Existing", chutesPairHotkey: "Cinder Node"]

        stub(directoryService) { stub in
            when(stub.createDetailWrapper(for: any(), subnet: any())).then { hotkey, subnet in
                guard !failingDetails.contains(hotkey) else {
                    return CompoundOperationWrapper.createWithError(
                        BittensorApiError.unavailable(code: nil, requestId: nil)
                    )
                }

                let take = hotkey == self.existingHotkey ? existingTake : Decimal(string: "0.09")

                return CompoundOperationWrapper.createWithResult(
                    self.generateItem(hotkey: hotkey, netuid: subnet.netuid, name: names[hotkey], take: take)
                )
            }
        }

        return directoryService
    }

    private func createRecommendationService() -> MockSubtensorRecommendationServiceProtocol {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()

        let recommended = SubtensorRecommendedValidators(
            validators: [
                SubtensorRecommendedValidator(hotkey: chutesPairHotkey, name: nil),
                SubtensorRecommendedValidator(hotkey: topYieldHotkey, name: "Rizzo"),
                SubtensorRecommendedValidator(hotkey: secondYieldHotkey, name: "Datura")
            ]
        )

        stub(recommendationService) { stub in
            when(stub.createRecommendedValidatorsWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(recommended)
            }
        }

        return recommendationService
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

    private func createYieldService(rates: [AccountId: String]? = nil) -> MockSubtensorYieldServiceProtocol {
        let yieldService = MockSubtensorYieldServiceProtocol()
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        stub(yieldService) { stub in
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

        return yieldService
    }

    private func createFactory(
        existingTake: Decimal?,
        recommendationService: SubtensorRecommendationServiceProtocol,
        yieldService: MockSubtensorYieldServiceProtocol? = nil,
        failingDetails: Set<AccountId> = []
    ) -> SubtensorValidatorPresetFactory {
        SubtensorValidatorPresetFactory(
            directoryService: createDirectoryService(existingTake: existingTake, failingDetails: failingDetails),
            recommendationService: recommendationService,
            yieldService: yieldService ?? createYieldService(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
