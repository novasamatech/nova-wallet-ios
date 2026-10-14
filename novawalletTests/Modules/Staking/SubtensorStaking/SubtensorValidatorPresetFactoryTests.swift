import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorValidatorPresetFactoryTests: XCTestCase {
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let existingHotkey = Data(repeating: 0x22, count: 32)
    private let chutesPairHotkey = Data(repeating: 0x55, count: 32)

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

        let names = [existingHotkey: "Existing", chutesPairHotkey: "Cinder Node"]

        stub(directoryService) { stub in
            when(stub.createDetailWrapper(for: any(), subnet: any())).then { hotkey, subnet in
                let take = hotkey == self.existingHotkey ? existingTake : Decimal(string: "0.09")

                return CompoundOperationWrapper.createWithResult(
                    self.generateItem(hotkey: hotkey, netuid: subnet.netuid, name: names[hotkey], take: take)
                )
            }
        }

        return directoryService
    }

    private func createRecommendationService(
        freshness: SubtensorBackendStamp.Freshness = .fresh
    ) -> MockSubtensorRecommendationServiceProtocol {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()

        let recommended = SubtensorRecommendedValidators(
            generation: SubtensorRecommendationGeneration(
                sourceBlockNumber: 9_139_880,
                carriedOverNetuids: [],
                stamp: SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: freshness)
            ),
            validators: [SubtensorRecommendedValidator(hotkey: chutesPairHotkey, name: nil)]
        )

        stub(recommendationService) { stub in
            when(stub.createRecommendedValidatorsWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(recommended)
            }
        }

        return recommendationService
    }

    private func createYieldService() -> MockSubtensorYieldServiceProtocol {
        let yieldService = MockSubtensorYieldServiceProtocol()

        stub(yieldService) { stub in
            when(stub.createAlphaYieldsWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithError(BittensorApiError.routeNotPublished)
            }
        }

        return yieldService
    }

    private func createFactory(
        existingTake: Decimal?,
        recommendationService: MockSubtensorRecommendationServiceProtocol
    ) -> SubtensorValidatorPresetFactory {
        SubtensorValidatorPresetFactory(
            directoryService: createDirectoryService(existingTake: existingTake),
            recommendationService: recommendationService,
            yieldService: createYieldService(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
