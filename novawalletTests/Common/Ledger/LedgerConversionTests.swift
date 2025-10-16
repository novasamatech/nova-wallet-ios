import XCTest
@testable import novawallet

final class LedgerConversionTests: XCTestCase {
    func testLedgerBuilderPathSameAsConverted() throws {
        // given
        for index in 0 ... 2 {
            let accountIndex = UInt32(index)

            for app in SupportedLedgerApp.substrate() {
                let expectedPath = LedgerPathBuilder().appendingStandardJunctions(
                    coin: app.coin,
                    accountIndex: accountIndex
                ).build()

                // when

                let converter = LedgerPathConverter()
                let stringValue = try converter.convertFromChaincodesData(from: expectedPath)
                let actualPath = try converter.convertToChaincodesData(from: stringValue)

                // then

                let expectedStringValue = "//44//\(app.coin)//\(accountIndex)//0//0"

                XCTAssertEqual(expectedStringValue, stringValue)
                XCTAssertEqual(expectedPath, actualPath)
            }
        }
    }

    func testEmptyPath() throws {
        // given

        let converter = LedgerPathConverter()

        // when

        let stringValue = try converter.convertFromChaincodesData(from: Data())

        // then

        XCTAssertEqual(stringValue, "")
    }

    func testSoftHardPath() throws {
        // given

        let expectedString = "//44/354//0/0//1"

        // when

        let converter = LedgerPathConverter()
        let actualPath = try converter.convertToChaincodesData(from: expectedString)
        let actualString = try converter.convertFromChaincodesData(from: actualPath)

        // then

        XCTAssertEqual(expectedString, actualString)
    }
}
