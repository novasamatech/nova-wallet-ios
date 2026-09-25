import XCTest
@testable import novawallet

final class SubtensorValidatorChainStatusTests: XCTestCase {
    let hotkey = AccountId(repeating: 7, count: 32)
    let head: BlockNumber = 9_139_740
    let cutoff = SubtensorValidatorChainStatus.effectiveActivityCutoff(factorMilli: 13889, tempo: 360)

    func testEffectiveActivityCutoffIsFactorTimesTempoOverThousandRoundedDown() {
        XCTAssertEqual(cutoff, 5000)
    }

    func testSubnetValidatorUpdatedExactlyCutoffBlocksAgoIsActive() {
        let status = makeStatus(netuid: 64, uid: 1, lastUpdate: UInt64(head) - cutoff)

        XCTAssertEqual(
            status,
            SubtensorValidatorChainStatus(uid: 1, hasPermit: true, blocksSinceUpdate: 5000, isActive: true)
        )
    }

    func testSubnetValidatorUpdatedOneBlockBeyondCutoffIsInactive() {
        let status = makeStatus(netuid: 64, uid: 1, lastUpdate: UInt64(head) - cutoff - 1)

        XCTAssertEqual(
            status,
            SubtensorValidatorChainStatus(uid: 1, hasPermit: true, blocksSinceUpdate: 5001, isActive: false)
        )
    }

    func testRootValidatorStatusCarriesOnlyTheUid() {
        let status = makeStatus(netuid: 0, uid: 1, lastUpdate: 0)

        XCTAssertEqual(
            status,
            SubtensorValidatorChainStatus(uid: 1, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil)
        )
    }

    func testUidOutsideTheSubnetVectorsYieldsNoStatus() {
        XCTAssertNil(makeStatus(netuid: 64, uid: 3, lastUpdate: UInt64(head)))
    }

    private func makeStatus(netuid: UInt16, uid: UInt16, lastUpdate: UInt64) -> SubtensorValidatorChainStatus? {
        let pair = SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)

        let snapshot = SubtensorValidatorChainSnapshot(
            blockHash: "0x8a6b1e2f4c3d5e7f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f",
            blockNumber: head,
            uids: [pair: uid],
            permits: [0: [false, false, false], 64: [false, true, false]],
            lastUpdates: [0: [0, 0, 0], 64: [0, lastUpdate, 0]],
            effectiveActivityCutoffs: [64: cutoff],
            takes: [hotkey: 11796],
            hotkeyAlpha: [:]
        )

        return SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair)
    }
}
