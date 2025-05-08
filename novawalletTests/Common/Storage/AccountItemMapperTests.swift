import XCTest
@testable import novawallet
import Operation_iOS
import NovaCrypto

class AccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem() throws {
        // given
        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        // when
        let keypair = try SECKeyFactory().createRandomKeypair()
        let address = try keypair.publicKey().rawData().toAddress(using: .substrate(2))
        let accountId = try keypair.publicKey().rawData().publicKeyToAccountId()

        let metaAccountItem = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "metaAccount",
            substrateAccountId: accountId,
            substrateCryptoType: MultiassetCryptoType.substrateEcdsa.rawValue,
            substratePublicKey: keypair.publicKey().rawData(),
            ethereumAddress: address.asSecretData(),
            ethereumPublicKey: keypair.publicKey().rawData(),
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )

        settings.save(value: metaAccountItem)

        // then

        XCTAssertTrue(settings.hasValue)

        // when
        let receivedMetaAccountItem = settings.value

        // then
        XCTAssertEqual(metaAccountItem, receivedMetaAccountItem)
    }
}
