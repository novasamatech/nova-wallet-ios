import XCTest
import FearlessUtils
import SoraKeystore
import RobinHood
@testable import fearless

class KeystoreExportWrapperTests: XCTestCase {
    func testSrAccountExport() {
        performExportTestForFilename(Constants.validSrKeystoreName,
                                     password: Constants.validSrKeystorePassword)
    }

    func testEd25519AccountExport() {
        performExportTestForFilename(Constants.validEd25519KeystoreName,
                                    password: Constants.validEd25519KeystorePassword)
    }

    func testEcdsaAccountExport() {
        performExportTestForFilename(Constants.validEcdsaKeystoreName,
                                    password: Constants.validEcdsaKeystorePassword)
    }

    // MARK: Private

    private func performExportTestForFilename(_ name: String,
                                              password: String) {
        do {
            // given

            let expectedKeystore = InMemoryKeychain()
            let expectedSettings = InMemorySettingsManager()

            try AccountCreationHelper.createAccountFromKeystore(
                name,
                password: password,
                keychain: expectedKeystore,
                settings: expectedSettings
            )

            let expectedAccountItem = expectedSettings.selectedAccount!
            let expectedSecretKey = try expectedKeystore.fetchSecretKeyForAddress(expectedAccountItem.address)

            // when

            let exportData = try KeystoreExportWrapper(keystore: expectedKeystore)
                .export(account: expectedAccountItem,
                        password: password)

            Logger.shared.debug("\(exportData.toUTF8String()!)")

            let resultKeystore = InMemoryKeychain()
            let resultSettings = InMemorySettingsManager()

            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exportData)

            let info = try AccountImportJsonFactory().createInfo(from: definition)

            try AccountCreationHelper.createAccountFromKeystoreData(exportData,
                                                                    password: password,
                                                                    keychain: resultKeystore,
                                                                    settings: resultSettings,
                                                                    networkType: info.networkType ?? .westend,
                                                                    cryptoType: .sr25519) // FIXME: cryptoType: info.cryptoType ?? .sr25519)

            // then

            let resultAccountItem = resultSettings.selectedAccount!
            let resultSecretKey = try expectedKeystore.fetchSecretKeyForAddress(resultAccountItem.address)

            XCTAssertEqual(expectedAccountItem, resultAccountItem)
            XCTAssertEqual(expectedSecretKey, resultSecretKey)

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
}
