import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorStakeInfoDecodeTests: XCTestCase {
    let stakeInfoForColdkeyHex = "0x04f8d0eafbd29c52d8de8454bc05cd74b9e6d3db0ce043d8e543566a7ca477084484cec003c237e96caf516d446e7ca347f1c1439539f915438a806f099e31fd1c00dad5c80d0000000000"

    let stakeAvailabilityHex = "0x0484cec003c237e96caf516d446e7ca347f1c1439539f915438a806f099e31fd1c080000dad5c80d00dad5c80d030002093d0042420f00c2c62d00"

    let hotkeyHex = "0xf8d0eafbd29c52d8de8454bc05cd74b9e6d3db0ce043d8e543566a7ca4770844"
    let coldkeyHex = "0x84cec003c237e96caf516d446e7ca347f1c1439539f915438a806f099e31fd1c"

    func testStakeInfoForColdkeyFixtureDecodes() throws {
        let stakeInfos: [SubtensorStakingPallet.StakeInfo] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: stakeInfoForColdkeyHex,
            path: SubtensorStakingPallet.stakeInfoForColdkeyApi
        )

        XCTAssertEqual(stakeInfos.count, 1)

        let stakeInfo = try XCTUnwrap(stakeInfos.first)

        XCTAssertEqual(stakeInfo.hotkey, try Data(hexString: hotkeyHex))
        XCTAssertEqual(stakeInfo.coldkey, try Data(hexString: coldkeyHex))
        XCTAssertEqual(stakeInfo.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertEqual(stakeInfo.stake, BigUInt(57_816_438))
        XCTAssertEqual(stakeInfo.locked, 0)
        XCTAssertEqual(stakeInfo.emission, 0)
        XCTAssertEqual(stakeInfo.taoEmission, 0)
        XCTAssertEqual(stakeInfo.drain, 0)
        XCTAssertFalse(stakeInfo.isRegistered)
    }

    func testStakeAvailabilityByColdkeyDecodes() throws {
        let availabilities: [SubtensorStakingPallet.ColdkeyStakeAvailability] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: stakeAvailabilityHex,
            path: SubtensorStakingPallet.stakeAvailabilityForColdkeysApi
        )

        XCTAssertEqual(availabilities.count, 1)

        let coldkeyAvailability = try XCTUnwrap(availabilities.first)

        XCTAssertEqual(coldkeyAvailability.coldkey, try Data(hexString: coldkeyHex))
        XCTAssertEqual(coldkeyAvailability.subnets.count, 2)

        let rootAvailability = try XCTUnwrap(coldkeyAvailability.subnets.first)

        XCTAssertEqual(rootAvailability.netuid, 0)
        XCTAssertEqual(rootAvailability.availability.total, BigUInt(57_816_438))
        XCTAssertEqual(rootAvailability.availability.locked, 0)
        XCTAssertEqual(rootAvailability.availability.available, BigUInt(57_816_438))

        let subnetAvailability = try XCTUnwrap(coldkeyAvailability.subnets.last)

        XCTAssertEqual(subnetAvailability.netuid, 3)
        XCTAssertEqual(subnetAvailability.availability.total, BigUInt(1_000_000))
        XCTAssertEqual(subnetAvailability.availability.locked, BigUInt(250_000))
        XCTAssertEqual(subnetAvailability.availability.available, BigUInt(750_000))
    }
}
