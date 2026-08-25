import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorDynamicInfoDecodeTests: XCTestCase {
    let dynamicInfoSliceHex = "0x0801000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010c901bd01bd01d101083903910291019a492c010e4af400000f63894fbb3d88040f3123ac5eeece130f1b74112a7f321300000000000f70f49d128e88c80000000000000000000000000000000000000104e2ee75ea11e4c5b7f5dac2e735278cfa0b1590c9856690f66653bdd85b709104e2ee75ea11e4c5b7f5dac2e735278cfa0b1590c9856690f66653bdd85b709104100501c1019501e101083903c5028d01e2922002c4000f4a7375806c740b0f43aa58b3d300090badebc44fbd1602286bee32491007ba050e0007b825e6ad08000f1755ebff00f502826b5b000110417065789068747470733a2f2f6769746875622e636f6d2f6d6163726f636f736d2d6f732f617065785068656c6c6f406d6163726f636f736d6f732e61696c68747470733a2f2f617065782e6d6163726f636f736d6f732e61697068747470733a2f2f646973636f72642e67672f627642446174334779845468652067656e6572616c20696e74656c6c6967656e636520706c6174666f726dcc68747470733a2f2f7777772e6d6163726f636f736d6f732e61692f696d616765732f6d635f6c6f676f5f626c61636b2e706e670054e3fc01000000000000000000000000"

    func testRootSubnetDecodesCompactByteStringsAndZeroMovingPrice() throws {
        let infos = try decodeSlice()

        let rootInfo = try XCTUnwrap(infos.first ?? nil)

        XCTAssertEqual(rootInfo.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertEqual(rootInfo.displayName, "root")
        XCTAssertEqual(rootInfo.displaySymbol, "Τ")
        XCTAssertEqual(rootInfo.ownerHotkey, Data(repeating: 0, count: 32))
        XCTAssertEqual(rootInfo.tempo, 100)
        XCTAssertEqual(rootInfo.lastStep, 4_919_910)
        XCTAssertEqual(rootInfo.emission, 0)
        XCTAssertEqual(rootInfo.alphaIn, BigUInt(1_275_698_623_777_123))
        XCTAssertEqual(rootInfo.alphaOut, BigUInt(5_575_547_743_380_273))
        XCTAssertEqual(rootInfo.taoIn, BigUInt(5_403_546_305_524_763))
        XCTAssertEqual(rootInfo.subnetVolume, BigUInt(56_445_139_121_206_384))
        XCTAssertEqual(rootInfo.networkRegisteredAt, 0)
        XCTAssertNil(rootInfo.subnetIdentity)
        XCTAssertEqual(rootInfo.movingPrice.bits?.stringValue, "0")
    }

    func testDynamicSubnetDecodesIdentityAndMovingPrice() throws {
        let infos = try decodeSlice()

        let apexInfo = try XCTUnwrap(infos.last ?? nil)

        XCTAssertEqual(apexInfo.netuid, 1)
        XCTAssertEqual(apexInfo.displayName, "Apex")
        XCTAssertEqual(apexInfo.displaySymbol, "α")
        XCTAssertEqual(apexInfo.tempo, 99)
        XCTAssertEqual(apexInfo.lastStep, 8_922_296)
        XCTAssertEqual(apexInfo.blocksSinceLastStep, 49)
        XCTAssertEqual(apexInfo.alphaIn, BigUInt(3_224_234_104_288_074))
        XCTAssertEqual(apexInfo.alphaOut, BigUInt(2_534_184_037_427_779))
        XCTAssertEqual(apexInfo.taoIn, BigUInt(25_002_342_935_469))
        XCTAssertEqual(apexInfo.alphaOutEmission, BigUInt(1_000_000_000))
        XCTAssertEqual(apexInfo.alphaInEmission, BigUInt(29_626_956))
        XCTAssertEqual(apexInfo.taoInEmission, BigUInt(229_742))
        XCTAssertEqual(apexInfo.pendingAlphaEmission, BigUInt(37_277_279_672))
        XCTAssertEqual(apexInfo.pendingRootEmission, 0)
        XCTAssertEqual(apexInfo.subnetVolume, BigUInt(832_334_595_839_255))
        XCTAssertEqual(apexInfo.networkRegisteredAt, 1_497_824)

        let identity = try XCTUnwrap(apexInfo.subnetIdentity)

        XCTAssertEqual(String(decoding: identity.subnetName, as: UTF8.self), "Apex")
        XCTAssertEqual(
            String(decoding: identity.githubRepo, as: UTF8.self),
            "https://github.com/macrocosm-os/apex"
        )

        XCTAssertEqual(apexInfo.movingPrice.bits?.stringValue, "33350484")
    }

    private func decodeSlice() throws -> [SubtensorStakingPallet.DynamicInfo?] {
        let infos: [SubtensorStakingPallet.DynamicInfo?] = try SubtensorFixtureDecoding.decodeRuntimeApiResult(
            from: dynamicInfoSliceHex,
            path: SubtensorStakingPallet.allDynamicInfoApi
        )

        XCTAssertEqual(infos.count, 2)

        return infos
    }
}
