import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorDelegateInfoDecodeTests: XCTestCase {
    let delegatesSliceHex = "0x04c42f48720ad28cdaf8b3ff6171a7e58ab73695616a7c60ff63e306538f7c2d3751b8044469cecee8c3276bd160b37c1267c1dd144297c96c635f5e009d7ef66494af6c042c044469cecee8c3276bd160b37c1267c1dd144297c96c635f5e009d7ef66494af6c082c8d01000000"

    let delegateHex = "0xc42f48720ad28cdaf8b3ff6171a7e58ab73695616a7c60ff63e306538f7c2d37"
    let nominatorHex = "0x4469cecee8c3276bd160b37c1267c1dd144297c96c635f5e009d7ef66494af6c"

    func testDelegateInfoDecodesCompactTakeAndNominators() throws {
        let delegates: [SubtensorStakingPallet.DelegateInfo] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: delegatesSliceHex,
            path: SubtensorStakingPallet.delegatesApi
        )

        XCTAssertEqual(delegates.count, 1)

        let delegate = try XCTUnwrap(delegates.first)

        XCTAssertEqual(delegate.delegateSs58, try Data(hexString: delegateHex))
        XCTAssertEqual(delegate.take, 11796)
        XCTAssertEqual(delegate.ownerSs58, try Data(hexString: nominatorHex))
        XCTAssertEqual(delegate.registeredNetuids, [11, 99])
        XCTAssertEqual(delegate.validatorPermitNetuids, [])
        XCTAssertEqual(delegate.returnPer1000, 0)
        XCTAssertEqual(delegate.totalDailyReturn, 0)

        XCTAssertEqual(delegate.nominators.count, 1)

        let nomination = try XCTUnwrap(delegate.nominators.first)

        XCTAssertEqual(nomination.nominator, try Data(hexString: nominatorHex))
        XCTAssertEqual(nomination.stakes.count, 1)

        let subnetStake = try XCTUnwrap(nomination.stakes.first)

        XCTAssertEqual(subnetStake.netuid, 11)
        XCTAssertEqual(subnetStake.stake, 1)
    }
}
