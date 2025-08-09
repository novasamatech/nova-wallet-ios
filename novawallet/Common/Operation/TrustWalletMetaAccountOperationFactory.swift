import Foundation
import SubstrateSdk
import NovaCrypto
import Operation_iOS
import Keystore_iOS

final class TrustWalletMetaAccountOperationFactory {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    // MARK: - Derivation functions

    func getJunctionResult(from derivationPath: String) throws -> JunctionResult? {
        guard !derivationPath.isEmpty else { return nil }

        let junctionFactory = BIP32JunctionFactory()

        return try junctionFactory.parse(path: derivationPath)
    }

    func deriveSeed(from mnemonic: String) throws -> SeedFactoryResult {
        try BIP32SeedFactory().deriveSeed(from: mnemonic, password: "")
    }

    // MARK: - Save functions

    func saveSecretKey(
        _ secretKey: Data,
        metaId: String,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveEntropy(_ entropy: Data, metaId: String) throws {
        let tag = KeystoreTagV2.entropyTagForMetaId(metaId)
        try keystore.saveKey(entropy, with: tag)
    }

    func saveDerivationPath(
        _ derivationPath: String,
        metaId: String,
        ethereumBased: Bool
    ) throws {
        guard !derivationPath.isEmpty,
              let derivationPathData = derivationPath.asSecretData()
        else { return }

        let tag = ethereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(metaId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(metaId)

        try keystore.saveKey(derivationPathData, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        metaId: String,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId(metaId) :
            KeystoreTagV2.substrateSeedTagForMetaId(metaId)

        try keystore.saveKey(seed, with: tag)
    }

    // MARK: - Keypair function

    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        isEthereumBased: Bool
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = isEthereumBased ? BIP32Secp256KeypairFactory() : BIP32Ed25519KeyFactory()

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        return (
            publicKey: keypair.publicKey().rawData(),
            secretKey: keypair.privateKey().rawData()
        )
    }

    // MARK: - Validation

    func validateRequest(_ request: MetaAccountCreationRequest) throws {
        guard request.cryptoType == .ed25519 else {
            throw MetaAccountOperationFactoryError.unsupportedCryptoType(request.cryptoType)
        }
    }
}

extension TrustWalletMetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {
    func newSecretsMetaAccountOperation(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            try validateRequest(request)

            let junctionResult = try getJunctionResult(from: request.derivationPath)

            let substrateChaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(from: mnemonic.toString())

            let substrateKeypair = try generateKeypair(
                from: seedResult.seed,
                chaincodes: substrateChaincodes,
                isEthereumBased: false
            )

            let ethereumJunctionResult = try getJunctionResult(from: request.ethereumDerivationPath)

            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let ethereumKeypair = try generateKeypair(
                from: seedResult.seed,
                chaincodes: ethereumChaincodes,
                isEthereumBased: true
            )

            let metaId = UUID().uuidString

            let substrateAccountId = try substrateKeypair.publicKey.publicKeyToAccountId()
            let ethereumAddress = try ethereumKeypair.publicKey.ethereumAddressFromPublicKey()

            try saveSecretKey(substrateKeypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seedResult.seed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumKeypair.secretKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(seedResult.seed, metaId: metaId, ethereumBased: true)

            try saveEntropy(mnemonic.entropy(), metaId: metaId)

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.username,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: substrateKeypair.publicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumKeypair.publicKey,
                chainAccounts: [],
                type: .secrets,
                multisig: nil
            )
        }
    }

    func newSecretsMetaAccountOperation(request _: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        .createWithError(MetaAccountOperationFactoryError.unsupportedMethod)
    }

    func newSecretsMetaAccountOperation(
        request _: MetaAccountImportKeystoreRequest
    ) -> BaseOperation<MetaAccountModel> {
        .createWithError(MetaAccountOperationFactoryError.unsupportedMethod)
    }

    func replaceChainAccountOperation(
        for _: MetaAccountModel,
        request _: ChainAccountImportMnemonicRequest,
        chainId _: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        .createWithError(MetaAccountOperationFactoryError.unsupportedMethod)
    }

    func replaceChainAccountOperation(
        for _: MetaAccountModel,
        request _: ChainAccountImportSeedRequest,
        chainId _: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        .createWithError(MetaAccountOperationFactoryError.unsupportedMethod)
    }

    func replaceChainAccountOperation(
        for _: MetaAccountModel,
        request _: ChainAccountImportKeystoreRequest,
        chainId _: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        .createWithError(MetaAccountOperationFactoryError.unsupportedMethod)
    }
}
