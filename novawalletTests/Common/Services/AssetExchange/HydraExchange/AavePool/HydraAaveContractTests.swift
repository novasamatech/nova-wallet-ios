import XCTest
@testable import novawallet
import SubstrateSdk

final class HydraAaveContractTests: XCTestCase {
    func testEncodesReserveDataCall() throws {
        let reserve = try Data(hexString: "0000000000000000000000000000000100000005")

        let call = try HydraAave.Contract.getReserveDataCall(reserve: reserve)

        XCTAssertEqual(
            call,
            "0x35ea6a75" + "000000000000000000000000" +
                "0000000000000000000000000000000100000005"
        )
    }

    func testDecodesReserveListUsingABIOffset() throws {
        let first = "0000000000000000000000000000000100000005"
        let second = "abcdefabcdefabcdefabcdefabcdefabcdefabcd"
        let response = abiWord(32) + abiWord(2) + addressWord(first) + addressWord(second)

        let reserves = try HydraAave.Contract.decodeReservesList(response: response)

        XCTAssertEqual(reserves.map { $0.toHex() }, [first, second])
    }

    func testDecodesATokenAddressFromReserveData() throws {
        let aToken = "1234567890abcdef1234567890abcdef12345678"
        let response = Array(repeating: abiWord(0), count: 8).joined() + addressWord(aToken)

        let decoded = try HydraAave.Contract.decodeATokenAddress(response: response)

        XCTAssertEqual(decoded.toHex(), aToken)
    }

    func testMapsPrecompileAndRegisteredContractAddresses() throws {
        let dotPrecompile = try Data(hexString: "0000000000000000000000000000000100000005")
        let aDotContract = try Data(hexString: "1234567890abcdef1234567890abcdef12345678")
        let registeredAssets = [aDotContract: HydraDx.AssetId(1001)]

        XCTAssertEqual(
            HydraAave.Contract.assetId(for: dotPrecompile, registeredAssets: registeredAssets),
            5
        )
        XCTAssertEqual(
            HydraAave.Contract.assetId(for: aDotContract, registeredAssets: registeredAssets),
            1001
        )
    }

    func testRejectsTruncatedABIResponse() {
        XCTAssertThrowsError(
            try HydraAave.Contract.decodeReservesList(response: abiWord(32))
        )
    }

    func testFindsAccountKey20InRuntimeLocation() throws {
        let accountId = "1234567890abcdef1234567890abcdef12345678"
        let keyBytes = try Data(hexString: accountId).map { JSON.stringValue(String($0)) }
        let location = JSON.dictionaryValue([
            "parents": .stringValue("0"),
            "interior": .arrayValue([
                .stringValue("X1"),
                .arrayValue([
                    .arrayValue([
                        .stringValue("AccountKey20"),
                        .dictionaryValue([
                            "network": .null,
                            "key": .arrayValue(keyBytes)
                        ])
                    ])
                ])
            ])
        ])

        XCTAssertEqual(
            HydraAave.Contract.findAccountKey20(in: location)?.toHex(),
            accountId
        )
    }
}

private extension HydraAaveContractTests {
    func abiWord(_ value: Int) -> String {
        String(value, radix: 16).leftPadding(toLength: 64, withPad: "0")
    }

    func addressWord(_ address: String) -> String {
        address.leftPadding(toLength: 64, withPad: "0")
    }
}
