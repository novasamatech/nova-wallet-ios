import XCTest
@testable import novawallet

final class SubtensorValidatorChainStatusTests: XCTestCase {
    private let hotkey = Data(repeating: 1, count: 32)
    private let netuid: UInt16 = 64

    func testHotkeyWithoutUidIsUnregistered() {
        XCTAssertEqual(makeStatus(childKeyPairs: []), .unregistered)
    }

    func testHotkeyWithoutUidButWithChildKeysIsViaChildKeys() {
        let status = makeStatus(childKeyPairs: [SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)])

        XCTAssertEqual(status, .viaChildKeys)
        XCTAssertFalse(SubtensorValidatorDirectoryItem(hotkey: hotkey, netuid: netuid, name: nil, status: status).isInactive)
    }

    func testChildKeysOnAnotherSubnetDoNotMakeHotkeyViaChildKeys() {
        let status = makeStatus(childKeyPairs: [SubtensorHotkeySubnet(hotkey: hotkey, netuid: 1)])

        XCTAssertEqual(status, .unregistered)
    }

    func testCoverageCountsChildSubnetsWithinCatalogue() {
        let delegate = SubtensorPallet.DelegateInfo(delegateSs58: hotkey, validatorPermits: [])

        let coverage = SubtensorValidatorCoverage.make(
            delegate: delegate,
            childNetuids: [1, 2, 999],
            catalogueNetuids: [1, 2, 3]
        )

        XCTAssertEqual(coverage, SubtensorValidatorCoverage(permitted: 2, total: 3))
    }

    private func makeStatus(childKeyPairs: Set<SubtensorHotkeySubnet>) -> SubtensorValidatorChainStatus? {
        let snapshot = SubtensorValidatorChainSnapshot(
            blockNumber: 100,
            uids: [:],
            permits: [:],
            lastUpdates: [:],
            effectiveActivityCutoffs: [:],
            takes: [:],
            childKeyPairs: childKeyPairs
        )

        return SubtensorValidatorChainStatus.make(
            snapshot: snapshot,
            pair: SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
        )
    }
}
