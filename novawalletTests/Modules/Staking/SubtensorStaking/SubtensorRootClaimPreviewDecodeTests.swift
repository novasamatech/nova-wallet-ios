import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorRootClaimPreviewDecodeTests: XCTestCase {
    let previewsHex = "0x08" +
        "bc0e6b701243978c1fe73d721c7b157943a713fca9f3c88cad7a9f7799bc6b26" +
        "d105880600000000b3eac805000000008cc5b005000000001b25180000000000" +
        "7d0000006700000016000000000000000a000000" +
        "b05b1de3868a6b49f218680ef3978d2ade38e04700a4006bd22ec529a7517045" +
        "3c1b1600000000008a830c00000000008c14000000000000c26e0c0000000000" +
        "7700000001000000760000000000000023000000"

    let firstHotkeyHex = "0xbc0e6b701243978c1fe73d721c7b157943a713fca9f3c88cad7a9f7799bc6b26"
    let secondHotkeyHex = "0xb05b1de3868a6b49f218680ef3978d2ade38e04700a4006bd22ec529a7517045"

    func testClaimPreviewsFixtureDecodes() throws {
        let previews: [SubtensorStakingPallet.BasketClaimPreview] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: previewsHex,
            path: SubtensorStakingPallet.rootBasketClaimPreviewsApi
        )

        XCTAssertEqual(
            previews,
            [
                SubtensorStakingPallet.BasketClaimPreview(
                    hotkey: try Data(hexString: firstHotkeyHex),
                    owedShares: 109_577_681,
                    accruedTao: BigUInt(97_053_363),
                    redeemableTao: BigUInt(95_470_988),
                    forfeitedTaoEst: BigUInt(1_582_363),
                    rows: 125,
                    rowsToSell: 103,
                    dustRows: 22,
                    swept: 0,
                    flushedCredits: 10
                ),
                SubtensorStakingPallet.BasketClaimPreview(
                    hotkey: try Data(hexString: secondHotkeyHex),
                    owedShares: 1_448_764,
                    accruedTao: BigUInt(820_106),
                    redeemableTao: BigUInt(5260),
                    forfeitedTaoEst: BigUInt(814_786),
                    rows: 119,
                    rowsToSell: 1,
                    dustRows: 118,
                    swept: 0,
                    flushedCredits: 35
                )
            ]
        )
    }
}
