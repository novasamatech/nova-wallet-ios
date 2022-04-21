import XCTest
@testable import novawallet
import RobinHood
import IrohaCrypto

class ETHAccountInjectionTest: XCTestCase {
    func testInjectETHAccount() throws {
        ///For inject account in simulator or device you should do:
        ///1. Find account that you want to add which operation in ETH chain
        ///2. Run script: https://github.com/stepanLav/helpful-utils/blob/master/derive_eth_publick_key_from_transaction.py
        ///3. Replace ethAddress,ethPublicKey with the values from the script above. And set the name.
        ///4. Run test


        // given
        let ethAddress = "0xE07c0A140F0Cb694a594Be70F84A74dcDB3BbFb0"
        let ethPublicKey = "0xb94b5bc1a86ccbbe4a1072101a5ca7fccf64b808d619c15e3bd34d5b1a141e8ef9e47474f5e74774914262212445882558df7c8446d51a093a191cf90de8a3f0"
        let name = "accountName"

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageFacade.shared,
            operationQueue: OperationQueue()
        )

        // when
        let keypair = try SECKeyFactory().createRandomKeypair()
        let accountId = try keypair.publicKey().rawData().publicKeyToAccountId()

        let metaAccountItem = MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: accountId,
            substrateCryptoType: MultiassetCryptoType.substrateEcdsa.rawValue,
            substratePublicKey: keypair.publicKey().rawData(),
            ethereumAddress: try Data(hexString: ethAddress),
            ethereumPublicKey: try Data(hexString: ethPublicKey),
            chainAccounts: []
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
