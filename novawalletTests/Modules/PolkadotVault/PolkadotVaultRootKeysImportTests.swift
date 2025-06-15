import XCTest
@testable import novawallet
import SubstrateSdk

final class PolkadotVaultRootKeysImportTests: XCTestCase {

    func testMatchRootKeys() throws {
        let encodedData = try Data(hexString: "4641464400b1dd88809b516102cef1cda69f3655072c2a5fd45ea1270d54228436108011464400b1dd88809b516102cef1cda69f3655072c2a5fd45ea1270d5422843610302164ccce2b5b037dd92156d9bed6e443ca721a5c16fe08c7b0cf562b5f20ab8f50ec11ec11ec11ec11")
        
        guard let actualData = encodedData.extractActualDataFromErrorCorrectedPayload() else {
            XCTFail("Expected data but found nil")
            return
        }
        
        let matcher = ParitySignerScanMatcher()
        
        let matchedFormat = matcher.match(code: .raw(Data(actualData)))
        
        XCTAssertNotNil(matchedFormat)
    }
}
