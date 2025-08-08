import XCTest
@testable import novawallet
import NovaCrypto
import Keystore_iOS

final class TrustWalletMetaAccountTests: XCTestCase {
    func testImportMnemonicFromTrustWallet() throws {
        // given
        
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "fine engage seed popular upon round differ belt engage space author pet"
        )
        
        let importRequest = MetaAccountCreationRequest(
            username: "Trust Wallet",
            derivationPath: DerivationPathConstants.trustWalletSubstrate,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .ed25519
        )
        
        let expectedAccountId = try "16PfWao1oeVQXAK6Qvj4owWVg49toh9ARbRmuCA3F2Gwxi3z".toAccountId()
        let expectedEthereumAddress = try "0x23502dd7D8357eB3E218269224031EE56A6DA84D".toEthereumAccountId()
        
        let keystore = InMemoryKeychain()
        let factory = TrustWalletMetaAccountOperationFactory(keystore: keystore)
        let operationQueue = OperationQueue()
        
        // when
        
        let operation = factory.newSecretsMetaAccountOperation(request: importRequest, mnemonic: mnemonic)
        
        operationQueue.addOperations([operation], waitUntilFinished: true)
        
        // then
        
        do {
            let metaAccount = try operation.extractNoCancellableResultData()
            
            XCTAssertEqual(metaAccount.name, importRequest.username)
            XCTAssertEqual(metaAccount.substrateCryptoType, importRequest.cryptoType.rawValue)
            
            XCTAssertEqual(metaAccount.substrateAccountId, expectedAccountId)
            XCTAssertEqual(metaAccount.ethereumAddress, expectedEthereumAddress)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
