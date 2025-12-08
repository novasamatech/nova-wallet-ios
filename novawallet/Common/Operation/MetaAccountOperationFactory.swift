import Foundation
import SubstrateSdk
import NovaCrypto
import Operation_iOS
import Keystore_iOS

protocol MetaAccountOperationFactoryProtocol {
    func newSecretsMetaAccountOperation(request: MetaAccountCreationRequest, mnemonic: IRMnemonicProtocol)
        -> BaseOperation<MetaAccountModel>
    func newSecretsMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel>
    func newSecretsMetaAccountOperation(request: MetaAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel>
    func newSecretsMetaAccountOperation(request: MetaAccountImportKeypairRequest) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportSeedRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeystoreRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>
}

final class MetaAccountOperationFactory {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    // MARK: - Factory functions

    func createKeypairFactory(_ cryptoType: MultiassetCryptoType) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .substrateEcdsa:
            return EcdsaKeypairFactory()
        case .ethereumEcdsa:
            return BIP32Secp256KeypairFactory()
        }
    }

    // MARK: - Derivation functions

    func getJunctionResult(
        from derivationPath: String,
        ethereumBased: Bool
    ) throws -> JunctionResult? {
        guard !derivationPath.isEmpty else { return nil }

        let junctionFactory = ethereumBased ?
            BIP32JunctionFactory() : SubstrateJunctionFactory()

        return try junctionFactory.parse(path: derivationPath)
    }

    func deriveSeed(
        from mnemonic: String,
        password: String,
        ethereumBased: Bool
    ) throws -> SeedFactoryResult {
        let seedFactory: SeedFactoryProtocol = ethereumBased ?
            BIP32SeedFactory() : SeedFactory()

        return try seedFactory.deriveSeed(from: mnemonic, password: password)
    }

    // MARK: - Save functions

    func saveSecretKey(
        _ secretKey: Data,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveEntropy(
        _ entropy: Data,
        metaId: String,
        accountId: AccountId? = nil
    ) throws {
        let tag = KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        try keystore.saveKey(entropy, with: tag)
    }

    func saveDerivationPath(
        _ derivationPath: String,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        guard !derivationPath.isEmpty,
              let derivationPathData = derivationPath.asSecretData()
        else { return }

        let tag = ethereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(derivationPathData, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(seed, with: tag)
    }

    // MARK: - Meta account generation function

    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: MultiassetCryptoType
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(cryptoType)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        switch cryptoType {
        case .sr25519, .ethereumEcdsa:
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: keypair.privateKey().rawData()
            )
        case .ed25519, .substrateEcdsa:
            guard let factory = keypairFactory as? DerivableSeedFactoryProtocol else {
                throw AccountOperationFactoryError.keypairFactoryFailure
            }

            let secretKey = try factory.deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: secretKey
            )
        }
    }

    func prepopulateMetaAccount(
        name: String,
        type: MetaAccountModelType,
        publicKey: Data,
        cryptoType: MultiassetCryptoType
    ) throws -> MetaAccountModel {
        guard cryptoType != .ethereumEcdsa else {
            throw AccountCreationError.unsupportedNetwork
        }

        let accountId = try publicKey.publicKeyToAccountId()

        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: accountId,
            substrateCryptoType: cryptoType.rawValue,
            substratePublicKey: publicKey,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: type,
            multisig: nil
        )
    }
}

// Implementation moved to corresponding extensions based on wallet type
extension MetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {}
