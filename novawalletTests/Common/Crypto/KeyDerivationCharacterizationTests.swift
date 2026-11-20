import Keystore_iOS
import NovaCrypto
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins key derivation and signing for wallets created from a mnemonic: public keys, a digest of the secret
/// stored in the keystore and deterministic signatures. A change here would silently produce different
/// accounts for the same mnemonic. Golden values were recorded on Crypto-iOS 0.4.1 / substrate-sdk-ios 4.5.2.
final class KeyDerivationCharacterizationTests: XCTestCase {
    /// The mnemonic `TrustWalletMetaAccountTests` already uses.
    private static let mnemonic = "fine engage seed popular upon round differ belt engage space author pet"
    private static let message = Data("nova wallet golden message".utf8)
    private static let sr25519ScalarLength = 32

    // MARK: Derivation

    func testSr25519Derivation() throws {
        XCTAssertEqual(try describeWallet(cryptoType: .sr25519, derivationPath: ""), "166969ba2d607c78bdd7caf2cd42824310b7463cb1bf0baa17bb477d15b20c6b|166969ba2d607c78bdd7caf2cd42824310b7463cb1bf0baa17bb477d15b20c6b|cde74a1343092fc7753f9019d67596cb59b3a4a3981168395989528a45ffa88e")
        XCTAssertEqual(try describeWallet(cryptoType: .sr25519, derivationPath: "//hard"), "8cfae01a8a78eb4d240fb83d1f46b5524ad7853132e7fa282393a92f8b2d9433|8cfae01a8a78eb4d240fb83d1f46b5524ad7853132e7fa282393a92f8b2d9433|1e5aeb6e324507fd480f29443664aa44428b86e46415ba2af60671c62789946d")
        XCTAssertEqual(try describeWallet(cryptoType: .sr25519, derivationPath: "/soft"), "7e563d20be9c8ff26bdd339ef4ab968e76dc9310378297c5f9204b139ec15b2b|7e563d20be9c8ff26bdd339ef4ab968e76dc9310378297c5f9204b139ec15b2b|1b9c0e3804cadcba79594489d559ef0f673bb1e5c9a3909eb1e3302cfc65ee15")
        XCTAssertEqual(try describeWallet(cryptoType: .sr25519, derivationPath: "//hard/soft//0"), "a4b89a980f33f524947fe1e55453823c7666b2a401ceca8974439e40f9462f3e|a4b89a980f33f524947fe1e55453823c7666b2a401ceca8974439e40f9462f3e|f49a86094fe4d80984ded7ab69938f5470f67b9ce162fbae7846afa8a4b75f46")
        XCTAssertEqual(try describeWallet(cryptoType: .sr25519, derivationPath: "//hard///password"), "1ada858853e91ba6d3f302560422f5b8d57102f7459c4ba9c5b8d3482e403e38|1ada858853e91ba6d3f302560422f5b8d57102f7459c4ba9c5b8d3482e403e38|f3f500b7f2fa9d7544e2f7b4607a16c1c84253b57ee2fcb03a51dbb13180d515")
    }

    func testEd25519Derivation() throws {
        XCTAssertEqual(try describeWallet(cryptoType: .ed25519, derivationPath: ""), "a99b92021c5bc4fe2a4cabfa5d4c1962774de1de02888852032c3bef16b07958|a99b92021c5bc4fe2a4cabfa5d4c1962774de1de02888852032c3bef16b07958|5705f69dc420a98feec2e58802c71f3ad6c857e56ee87909657c7f85f1229720")
        XCTAssertEqual(try describeWallet(cryptoType: .ed25519, derivationPath: "//hard//0"), "bc1313ee95ee54b4d277cd1c89d6fc8d026006f45e00451b5e630031849ebe69|bc1313ee95ee54b4d277cd1c89d6fc8d026006f45e00451b5e630031849ebe69|c2284562cbed5d14f48204be8768e867547df57b547e4eeb4a7fa459643914a5")
    }

    func testSubstrateEcdsaDerivation() throws {
        XCTAssertEqual(try describeWallet(cryptoType: .substrateEcdsa, derivationPath: ""), "03330187607e5d76b412080a19475bb10adaa3204a5bfc7a1115b19d8ba1a54785|dfed17da7ef8c81302fb3225bf1d4e1d514ccfddbb0f6e2422d9fd8c4869d9e6|5705f69dc420a98feec2e58802c71f3ad6c857e56ee87909657c7f85f1229720")
        XCTAssertEqual(try describeWallet(cryptoType: .substrateEcdsa, derivationPath: "//hard//0"), "02e34c0ef557cfc5cf0c1f451c698c56302d8901306c3a380154c9cc0c09589b17|57907dad43b4bc79dcd26fb98b7b8ae6327df5e3558e0ffad43450c0433986a6|d2834a81de85039173051c248d0ab4038be54e870bbd690e09363611a5f01ba9")
    }

    func testEthereumDerivation() throws {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: .sr25519, derivationPath: "", keychain: keychain)
        let secretKey = try keychain.fetchKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId))

        XCTAssertEqual(wallet.ethereumAddress?.toHex(includePrefix: true), "0x23502dd7d8357eb3e218269224031ee56a6da84d")
        XCTAssertEqual(wallet.ethereumPublicKey?.toHex(includePrefix: true), "0x02bcc434df9aa5ea2fc72717dbcbbd4beb2588cc2e86b4fcd704b03efb468ca1d0")
        XCTAssertEqual(try secretKey.blake2b32().toHex(includePrefix: true), "0x47e6ee0d1844bf49a800d85a890ce908c004e2740353956e4d874bedd5c3a79d")
    }

    func testSr25519StoredSecretIsReproducibleExceptSoftDerivedNonce() throws {
        XCTAssertEqual(try storedSecret(derivationPath: ""), try storedSecret(derivationPath: ""))
        XCTAssertEqual(try storedSecret(derivationPath: "//hard"), try storedSecret(derivationPath: "//hard"))

        let firstSoft = try storedSecret(derivationPath: "/soft")
        let secondSoft = try storedSecret(derivationPath: "/soft")

        XCTAssertEqual(firstSoft.count, 64)
        XCTAssertEqual(firstSoft.prefix(32), secondSoft.prefix(32))
        XCTAssertNotEqual(firstSoft.suffix(32), secondSoft.suffix(32))
    }

    func testSoftDerivationIsRejectedForEd25519AndEcdsa() {
        XCTAssertThrowsError(try describeWallet(cryptoType: .ed25519, derivationPath: "/soft"))
        XCTAssertThrowsError(try describeWallet(cryptoType: .substrateEcdsa, derivationPath: "/soft"))
    }

    func testSeedFromMnemonic() throws {
        let factory = MetaAccountOperationFactory(keystore: InMemoryKeychain())

        let substrate = try factory.deriveSeed(from: Self.mnemonic, password: "", ethereumBased: false)
        let substrateWithPassword = try factory.deriveSeed(from: Self.mnemonic, password: "pass", ethereumBased: false)
        let ethereum = try factory.deriveSeed(from: Self.mnemonic, password: "", ethereumBased: true)

        XCTAssertEqual(substrate.seed.count, 64)
        XCTAssertEqual(ethereum.seed.count, 64)
        XCTAssertEqual(try substrate.seed.blake2b32().toHex(includePrefix: true), "0xf5840f1aa6135b6c12c34b8da2f387029a61e69fb500d05c71af21e2b17e0c3c")
        XCTAssertEqual(try substrateWithPassword.seed.blake2b32().toHex(includePrefix: true), "0x946d6360c7301f4727944dcd246a1553c2b15df950dbb15a9c8e5280e742ec1a")
        XCTAssertEqual(try ethereum.seed.blake2b32().toHex(includePrefix: true), "0xd1d95335149ae82469896e9099cc9b4bf82c70990c6d9ffc620d3ae69541bcab")
    }

    // MARK: Signing

    /// The bundled ed25519 signer does not return the same bytes for the same key and message,
    /// so only validity is pinned for it.
    func testEd25519SignatureVerifies() throws {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: .ed25519, derivationPath: "//hard", keychain: keychain)
        let signer = makeSubstrateSigner(for: wallet, cryptoType: .ed25519, keychain: keychain)

        let signature = try signer.sign(Self.message, context: .rawBytes)

        XCTAssertEqual(signature.rawData().count, 64)
        XCTAssertTrue(
            EDSignatureVerifier().verify(
                signature,
                forOriginalData: Self.message,
                usingPublicKey: try EDPublicKey(rawData: try XCTUnwrap(wallet.substratePublicKey))
            )
        )
    }

    func testSubstrateEcdsaSignatureIsDeterministic() throws {
        XCTAssertEqual(try sign(cryptoType: .substrateEcdsa).toHex(includePrefix: true), "0xc1aa3a1e66d699535b47522a8b6c43fa3b48817ce1cd59e4bd72fb979f20141955e8d6b583eb81614e823a225f142cb3556ac724959b695988736ff8db3001fc01")
    }

    func testEthereumSignatureIsDeterministic() throws {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: .sr25519, derivationPath: "", keychain: keychain)
        let signer = SigningWrapper(
            keystore: keychain,
            metaId: wallet.metaId,
            accountId: nil,
            isEthereumBased: true,
            cryptoType: .ethereumEcdsa,
            publicKeyData: try XCTUnwrap(wallet.ethereumPublicKey),
            settingsManager: InMemorySettingsManager()
        )

        let signature = try signer.sign(Self.message, context: .rawBytes).rawData()

        XCTAssertEqual(signature.toHex(includePrefix: true), "0x4b08d60036b585e233edb3fea9449d5fd794123043a63c24b7374315a2c050f009a51225c88514555caf345c9983a0283054c60bcdeb75786ba534dc34723c1c01")
    }

    func testSr25519SignatureVerifiesAndIsRandomized() throws {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: .sr25519, derivationPath: "//hard/soft", keychain: keychain)
        let publicKeyData = try XCTUnwrap(wallet.substratePublicKey)
        let signer = makeSubstrateSigner(for: wallet, cryptoType: .sr25519, keychain: keychain)

        let first = try signer.sign(Self.message, context: .rawBytes).rawData()
        let second = try signer.sign(Self.message, context: .rawBytes).rawData()

        XCTAssertEqual(first.count, 64)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(
            SNSignatureVerifier().verify(
                try SNSignature(rawData: first),
                forOriginalData: Self.message,
                using: try SNPublicKey(rawData: publicKeyData)
            )
        )
    }
}

private extension KeyDerivationCharacterizationTests {
    func createWallet(
        cryptoType: MultiassetCryptoType,
        derivationPath: String,
        keychain: KeystoreProtocol
    ) throws -> MetaAccountModel {
        let request = MetaAccountCreationRequest(
            username: "Golden",
            derivationPath: derivationPath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: cryptoType
        )

        let operation = MetaAccountOperationFactory(keystore: keychain).newSecretsMetaAccountOperation(
            request: request,
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: Self.mnemonic)
        )

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    /// `public key | account id | blake2b-256 of the stored secret key`; the secret itself never enters the repo.
    /// For sr25519 only the scalar half is digested: schnorrkel draws a fresh nonce half on every soft derivation.
    func describeWallet(cryptoType: MultiassetCryptoType, derivationPath: String) throws -> String {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: cryptoType, derivationPath: derivationPath, keychain: keychain)
        let secretKey = try keychain.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
        let reproduciblePart = cryptoType == .sr25519 ? secretKey.prefix(Self.sr25519ScalarLength) : secretKey

        return [
            wallet.substratePublicKey?.toHex() ?? "nil",
            wallet.substrateAccountId?.toHex() ?? "nil",
            try Data(reproduciblePart).blake2b32().toHex()
        ]
        .joined(separator: "|")
    }

    func storedSecret(derivationPath: String) throws -> Data {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: .sr25519, derivationPath: derivationPath, keychain: keychain)

        return try keychain.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
    }

    func makeSubstrateSigner(
        for wallet: MetaAccountModel,
        cryptoType: MultiassetCryptoType,
        keychain: KeystoreProtocol
    ) -> SigningWrapper {
        SigningWrapper(
            keystore: keychain,
            metaId: wallet.metaId,
            accountId: nil,
            isEthereumBased: false,
            cryptoType: cryptoType,
            publicKeyData: wallet.substratePublicKey ?? Data(),
            settingsManager: InMemorySettingsManager()
        )
    }

    func sign(cryptoType: MultiassetCryptoType) throws -> Data {
        let keychain = InMemoryKeychain()
        let wallet = try createWallet(cryptoType: cryptoType, derivationPath: "//hard", keychain: keychain)
        let signer = makeSubstrateSigner(for: wallet, cryptoType: cryptoType, keychain: keychain)

        return try signer.sign(Self.message, context: .rawBytes).rawData()
    }
}
