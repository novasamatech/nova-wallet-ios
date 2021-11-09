import XCTest
import SubstrateSdk
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
            let facade = UserDataStorageTestFacade()

            let keystore = InMemoryKeychain()
            let settings = SelectedWalletSettings(
                storageFacade: facade, operationQueue: OperationQueue()
            )

            try AccountCreationHelper.createMetaAccountFromKeystore(
                name,
                password: password,
                keychain: keystore,
                settings: settings
            )

            let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 2)
            let expectedWallet = settings.value!

            let secretTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(expectedWallet.metaId)
            let expectedSecretKey = try keystore.loadIfKeyExists(secretTag)

            // when

            let exportData = try KeystoreExportWrapper(keystore: keystore)
                .export(metaAccount: expectedWallet, chain: chain, password: password)

            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exportData)

            let info = try AccountImportJsonFactory().createInfo(from: definition)

            try AccountCreationHelper.createMetaAccountFromKeystoreData(
                exportData,
                password: password,
                keychain: keystore,
                settings: settings,
                cryptoType: info.cryptoType ?? .sr25519
            )

            // then

            let resultWallet = settings.value!

            let resultSecretTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(resultWallet.metaId)
            let resultSecretKey = try keystore.loadIfKeyExists(resultSecretTag)

            XCTAssertEqual(expectedWallet.chainAccounts, resultWallet.chainAccounts)
            XCTAssertEqual(expectedWallet.ethereumAddress, resultWallet.ethereumAddress)
            XCTAssertEqual(expectedWallet.ethereumPublicKey, resultWallet.ethereumPublicKey)
            XCTAssertEqual(expectedWallet.substrateAccountId, resultWallet.substrateAccountId)
            XCTAssertEqual(expectedWallet.substratePublicKey, resultWallet.substratePublicKey)
            XCTAssertEqual(expectedWallet.substrateCryptoType, resultWallet.substrateCryptoType)
            XCTAssertEqual(expectedWallet.name, resultWallet.name)
            XCTAssertEqual(expectedSecretKey, resultSecretKey)

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
}
