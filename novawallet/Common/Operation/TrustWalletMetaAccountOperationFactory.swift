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
}

private extension TrustWalletMetaAccountOperationFactory {
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
    
    // MARK: - Chain Accounts
    
    func populateChainAccounts(
        for metaId: MetaAccountModel.Id,
        mnemonic: String
    ) -> [ChainAccountModel] {
        supportedChainAccountsDerivationPaths()
            .mapValues {
                ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    derivationPath: $0.derivationPath,
                    cryptoType: $0.cryptoType
                )
            }
            .compactMap {
                try? populateChainAccount(
                    for: metaId,
                    request: $0.value,
                    chainId: $0.key
                )
            }
    }
    
    func populateChainAccount(
        for metaId: MetaAccountModel.Id,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) throws -> ChainAccountModel {
        let ethereumBased = request.cryptoType == .ethereumEcdsa
        
        let junctionResult = try getJunctionResult(
            from: request.derivationPath
        )

        let password = junctionResult?.password ?? ""
        let chaincodes = junctionResult?.chaincodes ?? []

        let seedResult = try self.deriveSeed(
            from: request.mnemonic
        )
        
        let keypair = try generateKeypair(
            from: seedResult.seed,
            chaincodes: chaincodes,
            isEthereumBased: ethereumBased
        )

        let publicKey = keypair.publicKey
        let accountId = ethereumBased
            ? try publicKey.ethereumAddressFromPublicKey()
            : try publicKey.publicKeyToAccountId()

        try saveSecretKey(
            keypair.secretKey,
            metaId: metaId,
            accountId: accountId,
            ethereumBased: ethereumBased
        )
        try saveDerivationPath(
            request.derivationPath,
            metaId: metaId,
            accountId: accountId,
            ethereumBased: ethereumBased
        )
        try saveSeed(
            seedResult.seed,
            metaId: metaId,
            accountId: accountId,
            ethereumBased: ethereumBased
        )
        try saveEntropy(
            seedResult.mnemonic.entropy(),
            metaId: metaId,
            accountId: accountId
        )

        return ChainAccountModel(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: request.cryptoType.rawValue,
            proxy: nil,
            multisig: nil
        )
    }
    
    func supportedChainAccountsDerivationPaths() -> [ChainModel.Id: ChainAccountDerivation] {
        [
            KnowChainId.kusama: ChainAccountDerivation(
                derivationPath: "//44//434//0//0//0",
                cryptoType: .ed25519
            ),
            KnowChainId.kusamaAssetHub: ChainAccountDerivation(
                derivationPath: "//44//434//0//0//0",
                cryptoType: .ed25519
            )
        ]
    }
}

// MARK: - MetaAccountOperationFactoryProtocol

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

            let chainAccounts = populateChainAccounts(
                for: metaId,
                mnemonic: mnemonic.toString()
            )
            
            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: substrateKeypair.publicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumKeypair.publicKey,
                chainAccounts: Set(chainAccounts),
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

// MARK: - Private Types

private extension TrustWalletMetaAccountOperationFactory {
    struct ChainAccountDerivation {
        let derivationPath: String
        let cryptoType: MultiassetCryptoType
    }
}
