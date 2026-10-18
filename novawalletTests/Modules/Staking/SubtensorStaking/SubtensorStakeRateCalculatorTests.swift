import XCTest
@testable import novawallet

final class SubtensorStakeRateCalculatorTests: XCTestCase {
    let ratedHotkey = Data(repeating: 1, count: 32)
    let otherRatedHotkey = Data(repeating: 2, count: 32)
    let unratedHotkey = Data(repeating: 3, count: 32)
    let subnet: UInt16 = 7
    let otherSubnet: UInt16 = 9

    func testRootRateIsWeightedByStake() {
        let rate = SubtensorStakeRateCalculator.rootRate(
            of: [
                position(hotkey: ratedHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 30),
                position(hotkey: otherRatedHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 10)
            ],
            in: yields(netuid: SubtensorStakingPallet.rootNetuid, freshness: .fresh)
        )

        XCTAssertEqual(rate, Decimal(string: "0.105"))
    }

    func testUnratedRootPositionHidesTheRate() {
        let rate = SubtensorStakeRateCalculator.rootRate(
            of: [
                position(hotkey: unratedHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 90),
                position(hotkey: ratedHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 10)
            ],
            in: yields(netuid: SubtensorStakingPallet.rootNetuid, freshness: .fresh)
        )

        XCTAssertNil(rate)
    }

    func testStaleYieldsHideTheRootRate() {
        let rate = SubtensorStakeRateCalculator.rootRate(
            of: [position(hotkey: ratedHotkey, netuid: SubtensorStakingPallet.rootNetuid, stake: 10)],
            in: yields(netuid: SubtensorStakingPallet.rootNetuid, freshness: .stale)
        )

        XCTAssertNil(rate)
    }

    func testSubnetRateIsWeightedByTaoValue() {
        let positions = [
            position(hotkey: ratedHotkey, netuid: subnet, stake: 60),
            position(hotkey: otherRatedHotkey, netuid: otherSubnet, stake: 10)
        ]
        let subnetYields = [
            subnet: yields(netuid: subnet, freshness: .fresh),
            otherSubnet: yields(netuid: otherSubnet, freshness: .fresh)
        ]

        let scale = SubtensorStakingPallet.alphaPriceScale

        let rate = SubtensorStakeRateCalculator.subnetRate(
            of: positions,
            in: subnetYields,
            prices: prices([subnet: scale / 2, otherSubnet: scale])
        )

        XCTAssertEqual(rate, Decimal(string: "0.105"))
        XCTAssertNil(SubtensorStakeRateCalculator.subnetRate(of: positions, in: subnetYields, prices: prices([subnet: 1])))
    }

    private func position(hotkey: AccountId, netuid: UInt16, stake: Balance) -> SubtensorStakingPosition {
        SubtensorStakingPosition(hotkey: hotkey, netuid: netuid, stakeAlpha: stake, isRegistered: true)
    }

    private func prices(_ taoPerAlpha: [UInt16: Balance]) -> SubtensorAlphaPrices {
        SubtensorAlphaPrices(catalogue: nil, taoPerAlpha: taoPerAlpha)
    }

    private func yields(netuid: UInt16, freshness: SubtensorBackendStamp.Freshness) -> SubtensorAlphaYields {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: freshness)

        return SubtensorAlphaYields(
            netuid: netuid,
            yields: [
                ratedHotkey: SubtensorReportedYield(reportedRate: "12", stamp: stamp),
                otherRatedHotkey: SubtensorReportedYield(reportedRate: "6", stamp: stamp)
            ],
            stamp: stamp
        )
    }
}
