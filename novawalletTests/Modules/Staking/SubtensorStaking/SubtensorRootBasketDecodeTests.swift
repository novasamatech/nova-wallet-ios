import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorRootBasketDecodeTests: XCTestCase {
    let emptyOwedHex = "0x0000000000000000"
    let owedHex = "0x2a0bac0700000000"

    let emptyPositionsHex = "0x00"

    let positionsHex = "0x08a8eb4153119d95c0fc6c143573d82fa07d68748261d64a42a70f896a286e9810" +
        "d30cda0a0000000012f3ab0700000000" +
        "4c050d14320d29d6efe752157b28985774b1d1a765f9a5e3dc4b67ff05d58411" +
        "ad150000000000001818000000000000"

    let firstHotkeyHex = "0xa8eb4153119d95c0fc6c143573d82fa07d68748261d64a42a70f896a286e9810"
    let secondHotkeyHex = "0x4c050d14320d29d6efe752157b28985774b1d1a765f9a5e3dc4b67ff05d58411"

    func testZeroOwedFixtureDecodes() throws {
        let owed: StringScaleMapper<Balance> = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: emptyOwedHex,
            path: SubtensorStakingPallet.rootBasketOwedApi
        )

        XCTAssertEqual(owed.value, 0)
    }

    func testOwedFixtureDecodes() throws {
        let owed: StringScaleMapper<Balance> = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: owedHex,
            path: SubtensorStakingPallet.rootBasketOwedApi
        )

        XCTAssertEqual(owed.value, BigUInt(128_715_562))
    }

    func testEmptyPositionsFixtureDecodes() throws {
        let positions: [SubtensorStakingPallet.RootBasketPosition] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: emptyPositionsHex,
            path: SubtensorStakingPallet.rootBasketPositionsApi
        )

        XCTAssertTrue(positions.isEmpty)
    }

    func testPositionsFixtureDecodes() throws {
        let positions: [SubtensorStakingPallet.RootBasketPosition] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: positionsHex,
            path: SubtensorStakingPallet.rootBasketPositionsApi
        )

        XCTAssertEqual(
            positions.map(\.hotkey),
            [try Data(hexString: firstHotkeyHex), try Data(hexString: secondHotkeyHex)]
        )
        XCTAssertEqual(positions.map(\.owedShares), [182_062_291, 5549])
        XCTAssertEqual(positions.map(\.payout), [BigUInt(128_709_394), BigUInt(6168)])
    }

    func testPositionPayoutsSumToOwed() throws {
        let owed: StringScaleMapper<Balance> = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: owedHex,
            path: SubtensorStakingPallet.rootBasketOwedApi
        )

        let positions: [SubtensorStakingPallet.RootBasketPosition] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: positionsHex,
            path: SubtensorStakingPallet.rootBasketPositionsApi
        )

        let totalPayout = positions.reduce(BigUInt.zero) { $0 + $1.payout }

        XCTAssertEqual(totalPayout, owed.value)
    }
}
