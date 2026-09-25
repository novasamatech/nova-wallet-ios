import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorValidatorChainOperationFactoryTests: XCTestCase {
    private typealias Pallet = SubtensorStakingPallet

    private let hotkeyA = Data(repeating: 0x0A, count: 32)
    private let hotkeyB = Data(repeating: 0x0B, count: 32)
    private let hotkeyC = Data(repeating: 0x0C, count: 32)
    private let ownerX = Data(repeating: 0x1A, count: 32)
    private let ownerY = Data(repeating: 0x1B, count: 32)

    func testSnapshotDecodesEveryItemAtOneBlockWithChainDefaults() throws {
        let world = SubtensorStorageWorld()
        let subnet64 = SubtensorStorageWorld.netuidKey(64)
        let subnet12 = SubtensorStorageWorld.netuidKey(12)
        let root = SubtensorStorageWorld.netuidKey(0)

        try world.set("0x1c768b00", at: world.prefix(of: SystemPallet.blockNumberPath))
        try world.set("0x0500", at: world.key(Pallet.uidsPath, subnet64, .identity, hotkeyA, .blake128Concat))
        try world.set("0x0700", at: world.key(Pallet.uidsPath, subnet64, .identity, hotkeyB, .blake128Concat))
        try world.set("0x0300", at: world.key(Pallet.uidsPath, root, .identity, hotkeyA, .blake128Concat))
        try world.set("0x200000000000010000", at: world.key(Pallet.validatorPermitPath, subnet64, .identity))
        try world.set(
            "0x20" + String(repeating: "0", count: 80) + "b8758b0000000000" + String(repeating: "0", count: 16) +
                "fc278b0000000000",
            at: world.key(Pallet.lastUpdatePath, subnet64, .identity)
        )
        try world.set("0x204e0000", at: world.key(Pallet.activityCutoffFactorMilliPath, subnet64, .identity))
        try world.set("0x6300", at: world.key(Pallet.tempoPath, subnet12, .identity))
        try world.set("0x2823", at: world.key(Pallet.delegatesTakePath, hotkeyA, .blake128Concat))
        try world.set(
            "0x0010a5d4e8000000",
            at: world.key(Pallet.totalHotkeyAlphaPath, hotkeyA, .blake128Concat, subnet64, .identity)
        )

        let pairA64 = SubtensorHotkeySubnet(hotkey: hotkeyA, netuid: 64)
        let pairB64 = SubtensorHotkeySubnet(hotkey: hotkeyB, netuid: 64)
        let pairA0 = SubtensorHotkeySubnet(hotkey: hotkeyA, netuid: 0)
        let pairC12 = SubtensorHotkeySubnet(hotkey: hotkeyC, netuid: 12)

        let snapshot = try fetchSnapshot(
            world: world,
            query: SubtensorValidatorChainQuery(pairs: [pairA64, pairB64, pairA0, pairC12], includesHotkeyAlpha: true)
        )

        XCTAssertEqual(snapshot.blockHash, world.blockHash.toHex(includePrefix: true))
        XCTAssertEqual(snapshot.blockNumber, 9_139_740)
        XCTAssertEqual(snapshot.uids, [pairA64: 5, pairB64: 7, pairA0: 3])
        XCTAssertEqual(snapshot.permits, [64: [false, false, false, false, false, true, false, false], 12: []])
        XCTAssertEqual(snapshot.lastUpdates, [64: [0, 0, 0, 0, 0, 9_139_640, 0, 9_119_740], 12: []])
        XCTAssertEqual(
            snapshot.effectiveActivityCutoffs,
            [
                64: SubtensorValidatorChainStatus.effectiveActivityCutoff(factorMilli: 20000, tempo: 360),
                12: SubtensorValidatorChainStatus.effectiveActivityCutoff(factorMilli: 13889, tempo: 99)
            ]
        )
        XCTAssertEqual(snapshot.takes, [hotkeyA: 9000, hotkeyB: 11796, hotkeyC: 11796])
        XCTAssertEqual(
            snapshot.hotkeyAlpha,
            [pairA64: BigUInt(1_000_000_000_000), pairB64: 0, pairA0: 0, pairC12: 0]
        )

        XCTAssertTrue(world.recordedQueries.allSatisfy { $0.blockHash == world.blockHash })

        let rootEpochKeys = try [
            Pallet.validatorPermitPath,
            Pallet.lastUpdatePath,
            Pallet.tempoPath,
            Pallet.activityCutoffFactorMilliPath
        ].map { try world.key($0, root, .identity) }

        XCTAssertTrue(world.requestedKeys().isDisjoint(with: rootEpochKeys))
    }

    func testSnapshotSplitsEveryReadIntoChunksOf256DistinctKeys() throws {
        let world = SubtensorStorageWorld()
        let subnet64 = SubtensorStorageWorld.netuidKey(64)

        let hotkeys = (0 ..< 257).map { index in
            Data([UInt8(index & 0xFF), UInt8(index >> 8)] + [UInt8](repeating: 0x5E, count: 30))
        }

        try world.set("0x1c768b00", at: world.prefix(of: SystemPallet.blockNumberPath))
        try world.set("0x0900", at: world.key(Pallet.uidsPath, subnet64, .identity, hotkeys[256], .blake128Concat))
        try world.set("0x2a00", at: world.key(Pallet.delegatesTakePath, hotkeys[255], .blake128Concat))

        let pairs = hotkeys.map { SubtensorHotkeySubnet(hotkey: $0, netuid: 64) }

        let snapshot = try fetchSnapshot(
            world: world,
            query: SubtensorValidatorChainQuery(pairs: pairs + [pairs[0]], includesHotkeyAlpha: false)
        )

        XCTAssertEqual(try world.requestedKeyCounts(for: Pallet.uidsPath).sorted(), [1, 256])
        XCTAssertEqual(try world.requestedKeyCounts(for: Pallet.delegatesTakePath).sorted(), [1, 256])
        XCTAssertTrue(world.recordedQueries.allSatisfy { $0.keys.count <= 256 })
        XCTAssertEqual(snapshot.uids, [pairs[256]: 9])
        XCTAssertEqual(snapshot.takes.count, 257)
        XCTAssertEqual(snapshot.takes[hotkeys[255]], 42)
        XCTAssertEqual(snapshot.takes[hotkeys[256]], 11796)
        XCTAssertTrue(snapshot.hotkeyAlpha.isEmpty)
    }

    func testSnapshotFailsWhenStorageQueryFails() throws {
        let world = SubtensorStorageWorld()

        let query = SubtensorValidatorChainQuery(
            pairs: [SubtensorHotkeySubnet(hotkey: hotkeyA, netuid: 64)],
            includesHotkeyAlpha: false
        )

        XCTAssertThrowsError(try fetchSnapshot(world: world, query: query, failingStorage: true))
    }

    func testIdentitiesResolveOwnersThenDecodeIdentitiesV2() throws {
        let world = SubtensorStorageWorld()
        let hotkeyD = Data(repeating: 0x0D, count: 32)

        try world.set(ownerX.toHex(includePrefix: true), at: world.key(Pallet.ownerPath, hotkeyA, .blake128Concat))
        try world.set(ownerX.toHex(includePrefix: true), at: world.key(Pallet.ownerPath, hotkeyB, .blake128Concat))
        try world.set(ownerY.toHex(includePrefix: true), at: world.key(Pallet.ownerPath, hotkeyC, .blake128Concat))
        try world.set(
            "0x4820204e6f76612056616c696461746f7220205068747470733a2f2f6e6f76612e6578616d706c6500000420185374616b65730478",
            at: world.key(Pallet.identitiesV2Path, ownerX, .blake128Concat)
        )

        let engine = world.makeEngine()
        let factory = try SubtensorValidatorChainOperationFactory(
            runtimeConnectionStore: world.makeConnectionStore(engine: engine)
        )

        let identities = try run(factory.createIdentitiesWrapper(for: [hotkeyA, hotkeyB, hotkeyC, hotkeyD]))

        let expected = SubtensorValidatorIdentity(
            name: "Nova Validator",
            url: "https://nova.example",
            githubRepo: nil,
            image: nil,
            discord: nil,
            description: "Stakes"
        )

        XCTAssertEqual(identities, [hotkeyA: expected, hotkeyB: expected])
        XCTAssertEqual(try world.requestedKeyCounts(for: Pallet.identitiesV2Path), [2])
    }

    private func fetchSnapshot(
        world: SubtensorStorageWorld,
        query: SubtensorValidatorChainQuery,
        failingStorage: Bool = false
    ) throws -> SubtensorValidatorChainSnapshot {
        let engine = world.makeEngine(failingStorage: failingStorage)
        let factory = try SubtensorValidatorChainOperationFactory(
            runtimeConnectionStore: world.makeConnectionStore(engine: engine)
        )

        return try run(factory.createChainSnapshotWrapper(for: query))
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
