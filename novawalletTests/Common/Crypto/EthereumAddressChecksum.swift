import XCTest
@testable import novawallet

class EthereumAddressChecksum: XCTestCase {

    func testChecksumValid() {
        XCTAssertTrue("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed".isEthereumChecksumValid())
        XCTAssertTrue("0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359".isEthereumChecksumValid())
        XCTAssertTrue("0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB".isEthereumChecksumValid())
        XCTAssertTrue("0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb".isEthereumChecksumValid())
    }
}
