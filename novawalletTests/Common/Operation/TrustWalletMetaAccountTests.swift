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

        let expectedSubstrateAccountId = try "16PfWao1oeVQXAK6Qvj4owWVg49toh9ARbRmuCA3F2Gwxi3z".toAccountId()
        let expectedEthereumAddress = try "0x23502dd7D8357eB3E218269224031EE56A6DA84D".toEthereumAccountId()
        let expectedKusamaAccountId = try "DCZqFzNYLtn68HSk4VXRucbQAKSSD9x9YBQCqrHrAR4Vg2e".toAccountId()

        let expectedChainAccountChainIds: Set<ChainModel.Id> = [
            KnowChainId.kusama,
            KnowChainId.kusamaAssetHub
        ]

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

            XCTAssertEqual(metaAccount.substrateAccountId, expectedSubstrateAccountId)
            XCTAssertEqual(metaAccount.ethereumAddress, expectedEthereumAddress)

            XCTAssert(metaAccount.chainAccounts.contains { $0.accountId == expectedKusamaAccountId })
            XCTAssert(Set(metaAccount.chainAccounts.map(\.chainId)) == expectedChainAccountChainIds)

            XCTAssertNoThrow(try keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(metaAccount.metaId)))
            XCTAssertNoThrow(try keystore.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaAccount.metaId)))
            XCTAssertNoThrow(try keystore.fetchKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaAccount.metaId)))
            XCTAssertNoThrow(try keystore.fetchKey(for: KeystoreTagV2.ethereumSeedTagForMetaId(metaAccount.metaId)))
            XCTAssertNoThrow(try keystore.fetchKey(for: KeystoreTagV2.substrateSeedTagForMetaId(metaAccount.metaId)))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
