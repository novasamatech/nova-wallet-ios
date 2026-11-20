import Keystore_iOS
@testable import novawallet
import Security
import XCTest

/// Pins the protection class of secrets written through `Keychain`, the keystore every signing path defaults to.
/// Recorded on Keystore-iOS 1.0.1, where the class is hardcoded; newer versions make it a constructor argument.
final class KeychainCharacterizationTests: XCTestCase {
    private let tag = "io.novawallet.tests.keychain-characterization"
    private let keychain = Keychain()

    override func tearDown() {
        try? keychain.deleteKey(for: tag)

        super.tearDown()
    }

    func testKeysAreStoredWhenUnlockedThisDeviceOnly() throws {
        try keychain.saveKey(Data([1, 2, 3]), with: tag)

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(tag.utf8),
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        let attributes = item as? [String: Any]

        XCTAssertEqual(status, errSecSuccess)
        XCTAssertEqual(
            attributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }

    func testSaveFetchUpdateDeleteRoundTrip() throws {
        XCTAssertFalse(try keychain.checkKey(for: tag))

        try keychain.saveKey(Data([1, 2, 3]), with: tag)
        XCTAssertTrue(try keychain.checkKey(for: tag))
        XCTAssertEqual(try keychain.fetchKey(for: tag), Data([1, 2, 3]))

        try keychain.saveKey(Data([9]), with: tag)
        XCTAssertEqual(try keychain.fetchKey(for: tag), Data([9]))

        try keychain.deleteKey(for: tag)
        XCTAssertFalse(try keychain.checkKey(for: tag))
        XCTAssertThrowsError(try keychain.fetchKey(for: tag))
    }
}
