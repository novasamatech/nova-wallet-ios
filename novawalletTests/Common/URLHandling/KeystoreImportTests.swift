import XCTest
import SubstrateSdk
@testable import novawallet

class KeystoreImportTests: XCTestCase {

    func testValidKeystore() {
        XCTAssertTrue(SecretImportService(logger: Logger.shared).handle(url: KeystoreDefinition.validURL))
    }

    func testInvalidKeystore() {
        XCTAssertFalse(SecretImportService(logger: Logger.shared).handle(url: KeystoreDefinition.invalidURL))
    }
}
