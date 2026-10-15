import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorSwapApiDecodeTests: XCTestCase {
    func testCapturedBuySimDecodesAmountsAndTaoFee() throws {
        let simSwapResult: SubtensorStakingPallet.SimSwapResult = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: "0x051b933b0000000059fb83491e000000fbae0700000000000000000000000000000000000000000064bf370400000000",
            path: SubtensorStakingPallet.simSwapTaoForAlphaApi
        )

        XCTAssertEqual(simSwapResult.taoAmount, BigUInt(999_496_453))
        XCTAssertEqual(simSwapResult.alphaAmount, BigUInt(130_082_405_209))
        XCTAssertEqual(simSwapResult.taoFee, BigUInt(503_547))
        XCTAssertEqual(simSwapResult.alphaFee, 0)
    }

    func testCapturedSellSimDecodesAmountsAndAlphaFee() throws {
        let simSwapResult: SubtensorStakingPallet.SimSwapResult = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: "0xb2338a3b000000006f7d9c451e0000000000000000000000ea7de70300000000884a0800000000000000000000000000",
            path: SubtensorStakingPallet.simSwapAlphaForTaoApi
        )

        XCTAssertEqual(simSwapResult.taoAmount, BigUInt(998_912_946))
        XCTAssertEqual(simSwapResult.alphaAmount, BigUInt(130_016_902_511))
        XCTAssertEqual(simSwapResult.taoFee, 0)
        XCTAssertEqual(simSwapResult.alphaFee, BigUInt(65_502_698))
    }

    func testStakeInfoForColdkeyDecodesRootStake() throws {
        let stakeInfos: [SubtensorStakingPallet.StakeInfo] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: "0x04f8d0eafbd29c52d8de8454bc05cd74b9e6d3db0ce043d8e543566a7ca477084484cec003c237e96caf516d446e7ca347f1c1439539f915438a806f099e31fd1c00dad5c80d0000000000",
            path: SubtensorStakingPallet.stakeInfoForColdkeyApi
        )

        let stakeInfo = try XCTUnwrap(stakeInfos.first)

        XCTAssertEqual(stakeInfos.count, 1)
        XCTAssertEqual(
            stakeInfo.hotkey,
            try Data(hexString: "0xf8d0eafbd29c52d8de8454bc05cd74b9e6d3db0ce043d8e543566a7ca4770844")
        )
        XCTAssertEqual(stakeInfo.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertEqual(stakeInfo.stake, BigUInt(57_816_438))
    }

    func testClaimPreviewsDecodeRedeemableTao() throws {
        let previews: [SubtensorStakingPallet.BasketClaimPreview] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: "0x08" +
                "bc0e6b701243978c1fe73d721c7b157943a713fca9f3c88cad7a9f7799bc6b26" +
                "d105880600000000b3eac805000000008cc5b005000000001b25180000000000" +
                "7d0000006700000016000000000000000a000000" +
                "b05b1de3868a6b49f218680ef3978d2ade38e04700a4006bd22ec529a7517045" +
                "3c1b1600000000008a830c00000000008c14000000000000c26e0c0000000000" +
                "7700000001000000760000000000000023000000",
            path: SubtensorStakingPallet.rootBasketClaimPreviewsApi
        )

        XCTAssertEqual(previews.map(\.redeemableTao), [BigUInt(95_470_988), BigUInt(5260)])
        XCTAssertEqual(previews.map(\.forfeitedTaoEst), [BigUInt(1_582_363), BigUInt(814_786)])
        XCTAssertEqual(
            previews.map(\.hotkey),
            [
                try Data(hexString: "0xbc0e6b701243978c1fe73d721c7b157943a713fca9f3c88cad7a9f7799bc6b26"),
                try Data(hexString: "0xb05b1de3868a6b49f218680ef3978d2ade38e04700a4006bd22ec529a7517045")
            ]
        )
    }
}
