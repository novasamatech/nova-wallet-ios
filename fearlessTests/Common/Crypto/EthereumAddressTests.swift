import XCTest
@testable import fearless

class EthereumAddressTests: XCTestCase {
    func testAddressFromPublicKey() {
        do {
            let pubKey = try Data(
                hexString: "0x02d661622161b7244c978795b743f4957e199b2400045330700496ec57885632c5"
            )

            let expectedAddress = "0xd7381d7f3920495B2e25E6404fD62b8Ce0632d74".lowercased()

            let actualAddress = try pubKey.ethereumAddressFromPublicKey().toHex(includePrefix: true)

            XCTAssertEqual(expectedAddress, actualAddress)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
