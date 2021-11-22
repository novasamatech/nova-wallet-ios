import XCTest
import SubstrateSdk
@testable import novawallet

class KeystoreImportTests: XCTestCase {

    func testValidKeystore() {
        XCTAssertTrue(KeystoreImportService(logger: Logger.shared).handle(url: KeystoreDefinition.validURL))
    }

    func testInvalidKeystore() {
        XCTAssertFalse(KeystoreImportService(logger: Logger.shared).handle(url: KeystoreDefinition.invalidURL))
    }
}
