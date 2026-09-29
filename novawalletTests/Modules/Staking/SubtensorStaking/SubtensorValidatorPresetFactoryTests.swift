import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorValidatorPresetFactoryTests: XCTestCase {
    private let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
    private let existingHotkey = Data(repeating: 0x22, count: 32)
    private let preferredHotkey = Data(repeating: 0x33, count: 32)

    func testExistingStakeOnTheNetuidIsPresetBeforeTheConfigValidator() throws {
        let directoryService = makeDirectoryService(existingTake: Decimal(string: "0.09"))

        let preset = try run(
            makeFactory(directoryService).createPresetWrapper(for: rootRef, existingHotkey: existingHotkey)
        )

        XCTAssertEqual(preset?.hotkey, existingHotkey)
        XCTAssertEqual(preset?.name, "Existing")
        verify(directoryService, never()).createPreferredValidatorWrapper(for: any())
    }

    func testConfigValidatorIsPresetWhenTheExistingValidatorTakesAboveTheGate() throws {
        let directoryService = makeDirectoryService(existingTake: Decimal(string: "0.5"))

        let preset = try run(
            makeFactory(directoryService).createPresetWrapper(for: rootRef, existingHotkey: existingHotkey)
        )

        XCTAssertEqual(preset?.hotkey, preferredHotkey)
        XCTAssertEqual(preset?.name, "Nova Wallet")
    }

    private func makeItem(hotkey: AccountId, name: String?, take: Decimal?) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: SubtensorStakingPallet.rootNetuid,
            name: name,
            take: take,
            reportedStake: nil,
            status: SubtensorValidatorChainStatus(uid: 1, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil),
            isNovaPreferred: hotkey == preferredHotkey
        )
    }

    private func makeDirectoryService(existingTake: Decimal?) -> MockSubtensorValidatorDirectoryServiceProtocol {
        let directoryService = MockSubtensorValidatorDirectoryServiceProtocol()

        let directory = SubtensorValidatorDirectory(
            subnet: rootRef,
            items: [
                makeItem(hotkey: existingHotkey, name: "Existing", take: existingTake),
                makeItem(hotkey: preferredHotkey, name: "Nova Wallet", take: Decimal(string: "0.09"))
            ],
            listStamp: nil,
            isPartial: false,
            isEnrichmentTruncated: false,
            chainBlock: 100
        )

        let existingDetail = SubtensorValidatorDetail(
            item: makeItem(hotkey: existingHotkey, name: nil, take: existingTake),
            identity: nil
        )

        let preferredItem = makeItem(hotkey: preferredHotkey, name: nil, take: Decimal(string: "0.09"))

        stub(directoryService) { stub in
            when(stub.createDirectoryWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(directory)
            }

            when(stub.createDetailWrapper(for: any(), subnet: any())).then { _ in
                CompoundOperationWrapper.createWithResult(existingDetail)
            }

            when(stub.createPreferredValidatorWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(preferredItem)
            }
        }

        return directoryService
    }

    private func makeFactory(
        _ directoryService: MockSubtensorValidatorDirectoryServiceProtocol
    ) -> SubtensorValidatorPresetFactory {
        let recommendationService = MockSubtensorRecommendationServiceProtocol()

        stub(recommendationService) { stub in
            when(stub.lastSeenClientGates()).thenReturn(nil)
        }

        return SubtensorValidatorPresetFactory(
            directoryService: directoryService,
            recommendationService: recommendationService,
            operationQueue: OperationQueue(),
            logger: Logger.shared
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
