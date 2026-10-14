import BigInt
@testable import novawallet
import XCTest

final class SubtensorQuickPickSelectorTests: XCTestCase {
    func testPoolFloorIsInclusiveAndRootNeverParticipates() throws {
        let snapshot = SubtensorQuickPickFixtures.snapshot([
            .init(0, pool: 9_000_000_000_000), .init(1, pool: 2_000_000_000_000),
            .init(2, pool: 1_999_999_999_999), .init(3, pool: 3_000_000_000_000)
        ])
        let candidates = try SubtensorQuickPickSelector().candidates(from: snapshot, order: .poolSize)
        XCTAssertEqual(candidates.map(\.netuid), [3, 1])
    }

    func testEveryTopTenIndexIsReachableWithExactExclusiveBound() throws {
        for count in [1, 9, 10, 11, 150] {
            let snapshot = SubtensorQuickPickFixtures.snapshot((1 ... count).map {
                .init(UInt16($0), pool: Balance(2_000_000_000_000 + $0))
            })
            var reached: [UInt16] = []
            for index in 0 ..< min(count, 10) {
                let selector = SubtensorQuickPickSelector { range in
                    XCTAssertEqual(range, 0 ..< min(count, 10))
                    return index
                }
                reached.append(try selector.select(from: snapshot, order: .poolSize).netuid)
            }
            XCTAssertEqual(reached, (max(count - 9, 1) ... count).reversed().map(UInt16.init))
        }
    }

    func testPoolAndAgeHaveDifferentExactTopTensWithoutReadinessGates() throws {
        let snapshot = SubtensorQuickPickFixtures.snapshot((1 ... 12).map {
            .init(UInt16($0), pool: Balance(2_000_000_000_000 + $0), registered: UInt64($0))
        }, prices: [:], enabled: [])
        let selector = SubtensorQuickPickSelector()
        XCTAssertEqual(try selector.candidates(from: snapshot, order: .age).map(\.netuid), Array(1 ... 10).map(UInt16.init))
        XCTAssertEqual(try selector.candidates(from: snapshot, order: .poolSize).map(\.netuid), Array((3 ... 12).reversed()).map(UInt16.init))
    }

    func testTiesStartInNetuidOrderRegardlessOfIncomingOrder() throws {
        let snapshot = SubtensorQuickPickFixtures.snapshot([.init(9), .init(2), .init(5)])
        for order in [SubtensorQuickPickOrder.poolSize, .age] {
            XCTAssertEqual(try SubtensorQuickPickSelector().candidates(from: snapshot, order: order).map(\.netuid), [2, 5, 9])
        }
    }

    func testEmptyIncompleteAndUnsupportedOrdersNeverCallRandomness() {
        let selector = SubtensorQuickPickSelector { _ in XCTFail("Unexpected draw"); return 0 }
        XCTAssertThrowsError(try selector.select(from: SubtensorQuickPickFixtures.snapshot([]), order: .poolSize))
        XCTAssertThrowsError(try selector.select(from: SubtensorQuickPickFixtures.snapshot([.init(1)], complete: false), order: .age))
        for order in [SubtensorQuickPickOrder.root, .apy] {
            XCTAssertThrowsError(try selector.select(from: SubtensorQuickPickFixtures.snapshot([.init(1)]), order: order))
        }
    }

    func testSourceProvenanceRejectsNilAndDuplicateRows() {
        let first = SubtensorQuickPickFixtures.dynamic(.init(1))
        XCTAssertTrue(SubtensorSubnetsService.isCompleteSnapshot([first]))
        XCTAssertFalse(SubtensorSubnetsService.isCompleteSnapshot([first, nil]))
        XCTAssertFalse(SubtensorSubnetsService.isCompleteSnapshot([first, first]))
    }
}

enum SubtensorQuickPickFixtures {
    struct Candidate {
        let netuid: UInt16
        let pool: Balance
        let registered: UInt64
        init(_ netuid: UInt16, pool: Balance = 2_000_000_000_000, registered: UInt64 = 100) {
            self.netuid = netuid; self.pool = pool; self.registered = registered
        }
    }

    static func snapshot(
        _ candidates: [Candidate],
        prices: [UInt16: Balance]? = nil,
        enabled: Set<UInt16>? = nil,
        complete: Bool = true
    ) -> SubtensorSubnetsInfo {
        SubtensorSubnetsInfo(
            subnets: candidates.map(dynamic), isComplete: complete,
            prices: prices ?? Dictionary(candidates.map { ($0.netuid, Balance(1_000_000)) }, uniquingKeysWith: { first, _ in first }),
            subtokenEnabled: enabled ?? Set(candidates.map(\.netuid)), ownerCut: SubtensorStakingPallet.defaultSubnetOwnerCut
        )
    }

    static func dynamic(_ candidate: Candidate) -> SubtensorStakingPallet.DynamicInfo {
        .init(
            netuid: candidate.netuid,
            ownerHotkey: Data(repeating: 1, count: 32),
            ownerColdkey: Data(repeating: 2, count: 32),
            subnetName: Data(),
            tokenSymbol: Data(),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: candidate.pool,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: candidate.registered,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }
}
