import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorPreflightFactoryTests: XCTestCase {
    private typealias Pallet = SubtensorStakingPallet

    private let coldkey = Data(repeating: 0x01, count: 32)
    private let hotkey = Data(repeating: 0x02, count: 32)
    private let owner = Data(repeating: 0x03, count: 32)

    func testRootPreflightReadsSubnetGatesFromChainInsteadOfBypassingThem() throws {
        let world = SubtensorStorageWorld()

        let preflight = try fetchPreflight(world: world, netuid: Pallet.rootNetuid)

        XCTAssertFalse(preflight.subnetExists)
        XCTAssertFalse(preflight.subtokenEnabled)
        XCTAssertFalse(preflight.hotkeyExists)
        XCTAssertNil(preflight.hotkeyOwner)
    }

    func testPreflightCarriesTheRawHotkeyOwner() throws {
        let world = SubtensorStorageWorld()
        let subnet = SubtensorStorageWorld.netuidKey(64)

        try world.set("0x01", at: world.key(Pallet.networksAddedPath, subnet, .identity))
        try world.set("0x01", at: world.key(Pallet.subtokenEnabledPath, subnet, .identity))
        try world.set(owner.toHex(includePrefix: true), at: world.key(Pallet.ownerPath, hotkey, .blake128Concat))

        let preflight = try fetchPreflight(world: world, netuid: 64)

        XCTAssertTrue(preflight.subnetExists)
        XCTAssertTrue(preflight.subtokenEnabled)
        XCTAssertTrue(preflight.hotkeyExists)
        XCTAssertEqual(preflight.hotkeyOwner, owner)
    }

    private func fetchPreflight(world: SubtensorStorageWorld, netuid: UInt16) throws -> SubtensorStakingPreflight {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createStakeAvailabilityWrapper(for: any(), netuids: any(), blockHash: any())).then { _ in
                CompoundOperationWrapper.createWithResult([])
            }
        }

        let operationQueue = OperationQueue()

        let factory = try SubtensorPreflightFactory(
            runtimeConnectionStore: world.makeConnectionStore(engine: world.makeEngine()),
            operationFactory: apiFactory,
            operationQueue: operationQueue
        )

        let wrapper = factory.createPreflightWrapper(for: coldkey, hotkey: hotkey, netuid: netuid)
        let completed = expectation(description: "preflight completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
