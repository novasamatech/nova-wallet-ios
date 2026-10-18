@testable import novawallet
import BigInt
import XCTest

final class SubtensorPortfolioBuilderTests: XCTestCase {
    private let firstHotkey = Data(repeating: 0x0A, count: 32)
    private let secondHotkey = Data(repeating: 0x0B, count: 32)
    private let thirdHotkey = Data(repeating: 0x0C, count: 32)

    func testGroupsRootAndSubnetsWithTotalsAndTaoValue() {
        let rootMember = position(hotkey: secondHotkey, netuid: 0, stake: 2_000_000_000)
        let rootPrimary = position(hotkey: firstHotkey, netuid: 0, stake: 5_000_000_000)
        let subnetMember = position(hotkey: thirdHotkey, netuid: 64, stake: 20_000_000_000)
        let subnetPrimary = position(hotkey: firstHotkey, netuid: 64, stake: 100_000_000_000)

        let rootAvailability = availability(total: 7_000_000_000, locked: 0)
        let subnetAvailability = availability(total: 120_000_000_000, locked: 20_000_000_000)

        let state = Multistaking.SubtensorState(
            positions: [rootMember, subnetMember, rootPrimary, subnetPrimary],
            availability: [0: rootAvailability, 64: subnetAvailability]
        )

        let portfolio = SubtensorPortfolioBuilder.build(state: state, prices: prices([64: 50_000_000]))

        let expected = SubtensorPortfolio(
            root: SubtensorPortfolioGroup(
                netuid: 0,
                positions: [rootPrimary, rootMember],
                totalAlpha: 7_000_000_000,
                redeemable: 0,
                taoValue: 7_000_000_000,
                availability: rootAvailability,
                primaryHotkey: firstHotkey
            ),
            subnets: [
                SubtensorPortfolioGroup(
                    netuid: 64,
                    positions: [subnetPrimary, subnetMember],
                    totalAlpha: 120_000_000_000,
                    redeemable: 0,
                    taoValue: 6_000_000_000,
                    availability: subnetAvailability,
                    primaryHotkey: firstHotkey
                )
            ],
            pricedTaoValue: 13_000_000_000,
            unpricedNetuids: []
        )

        XCTAssertEqual(portfolio, expected)
    }

    func testUnpricedSubnetsExcludedFromTotalAndOrderedLast() {
        let state = Multistaking.SubtensorState(
            positions: [
                position(hotkey: firstHotkey, netuid: 12, stake: 80_000_000_000),
                position(hotkey: firstHotkey, netuid: 64, stake: 120_000_000_000),
                position(hotkey: secondHotkey, netuid: 7, stake: 50_000_000_000),
                position(hotkey: secondHotkey, netuid: 19, stake: 300_000_000_000)
            ]
        )

        let portfolio = SubtensorPortfolioBuilder.build(
            state: state,
            prices: prices([7: 0, 19: 30_000_000, 64: 50_000_000])
        )

        XCTAssertNil(portfolio.root)
        XCTAssertEqual(portfolio.subnets.map(\.netuid), [19, 64, 7, 12])
        XCTAssertEqual(portfolio.subnets.map(\.taoValue), [9_000_000_000, 6_000_000_000, nil, nil])
        XCTAssertEqual(portfolio.pricedTaoValue, 15_000_000_000)
        XCTAssertEqual(portfolio.unpricedNetuids, [7, 12])
    }

    private func position(hotkey: AccountId, netuid: UInt16, stake: Balance) -> SubtensorPosition {
        SubtensorPosition(
            hotkey: hotkey,
            netuid: netuid,
            stakeAlpha: stake,
            isRegistered: true
        )
    }

    private func availability(total: Balance, locked: Balance) -> SubtensorPallet.StakeAvailability {
        SubtensorPallet.StakeAvailability(available: total - locked)
    }

    private func prices(_ taoPerAlpha: [UInt16: Balance]) -> SubtensorAlphaPrices {
        SubtensorAlphaPrices(catalogue: nil, taoPerAlpha: taoPerAlpha)
    }
}
