@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorRootHoldFactoryTests: XCTestCase {
    private typealias Pallet = SubtensorStakingPallet

    private let coldkey = Data(repeating: 0x01, count: 32)
    private let stampedHotkey = Data(repeating: 0x0A, count: 32)
    private let unstampedHotkey = Data(repeating: 0x0B, count: 32)

    func testHoldsReadTheIntervalAndEachHotkeyStampAtOneBlock() throws {
        let world = SubtensorStorageWorld()

        try world.set("0x201c000000000000", at: world.prefix(of: Pallet.rootStakeUnlockIntervalPath))
        try world.set(
            "0x2a748b0000000000",
            at: world.key(Pallet.lastColdkeyHotkeyStakeBlockPath, coldkey, .twox64Concat, stampedHotkey, .twox64Concat)
        )

        let factory = try SubtensorRootHoldFactory(
            runtimeConnectionStore: world.makeConnectionStore(engine: world.makeEngine())
        )

        let holds = try run(factory.createHoldsWrapper(coldkey: coldkey, hotkeys: [stampedHotkey, unstampedHotkey]))

        XCTAssertEqual(
            holds,
            [
                stampedHotkey: SubtensorRootHold(interval: 7200, lastStakeBlock: 9_139_242),
                unstampedHotkey: SubtensorRootHold(interval: 7200, lastStakeBlock: 0)
            ]
        )

        XCTAssertTrue(world.recordedQueries.allSatisfy { $0.blockHash == world.blockHash })
    }

    func testHoldRemainsUntilTheIntervalElapses() {
        let hold = SubtensorRootHold(interval: 7200, lastStakeBlock: 9_139_242)

        XCTAssertEqual(hold.remainingBlocks(at: 9_142_242), 4200)
    }

    func testHoldUnlocksOnceTheIntervalHasElapsed() {
        let hold = SubtensorRootHold(interval: 7200, lastStakeBlock: 9_139_242)

        XCTAssertEqual(hold.remainingBlocks(at: 9_146_442), 0)
    }

    func testStampAheadOfTheHeadKeepsTheWholeInterval() {
        let hold = SubtensorRootHold(interval: 7200, lastStakeBlock: 9_139_242)

        XCTAssertEqual(hold.remainingBlocks(at: 9_139_240), 7200)
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
