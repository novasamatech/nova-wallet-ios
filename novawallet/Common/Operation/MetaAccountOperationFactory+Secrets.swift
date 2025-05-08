import Foundation
import SubstrateSdk
import NovaCrypto
import Operation_iOS
import Keystore_iOS

extension MetaAccountOperationFactory {
    func newSecretsMetaAccountOperation(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(from: request.derivationPath, ethereumBased: false)

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: mnemonic.toString(),
                password: password,
                ethereumBased: false
            )

            let substrateKeypair = try generateKeypair(
                from: seedResult.seed.miniSeed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                type: .secrets,
                publicKey: substrateKeypair.publicKey,
                cryptoType: request.cryptoType
            )

            let ethereumJunctionResult = try getJunctionResult(
                from: request.ethereumDerivationPath,
                ethereumBased: true
            )

            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let ethereumSeedFactory = BIP32SeedFactory()
            let ethereumSeedResult = try ethereumSeedFactory.deriveSeed(from: mnemonic.toString(), password: password)

            let keypairFactory = createKeypairFactory(.ethereumEcdsa)

            let ethereumKeypair = try keypairFactory.createKeypairFromSeed(
                ethereumSeedResult.seed,
                chaincodeList: ethereumChaincodes
            )

            let ethereumSecretKey = ethereumKeypair.privateKey().rawData()
            let ethereumPublicKey = ethereumKeypair.publicKey().rawData()
            let ethereumAddress = try ethereumPublicKey.ethereumAddressFromPublicKey()

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateKeypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seedResult.seed.miniSeed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumSecretKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumSeedResult.seed, metaId: metaId, ethereumBased: true)

            try saveEntropy(mnemonic.entropy(), metaId: metaId)

            return metaAccount.replacingEthereumPublicKey(ethereumPublicKey)
                .replacingEthereumAddress(ethereumAddress)
        }
    }

    func newSecretsMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: false
            )

            let chaincodes = junctionResult?.chaincodes ?? []
            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                type: .secrets,
                publicKey: keypair.publicKey,
                cryptoType: request.cryptoType
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(keypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seed, metaId: metaId, ethereumBased: false)

            return metaAccount
        }
    }

    func newSecretsMetaAccountOperation(request: MetaAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .substrateEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            case .ethereumEcdsa:
                throw AccountCreationError.unsupportedNetwork
            }

            let metaId = UUID().uuidString
            let accountId = try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: accountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: publicKey.rawData(),
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .secrets,
                multisig: nil
            )
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: ethereumBased
            )

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: request.mnemonic,
                password: password,
                ethereumBased: ethereumBased
            )

            let seed = ethereumBased ? seedResult.seed : seedResult.seed.miniSeed
            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = ethereumBased ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

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

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)
            try saveEntropy(seedResult.mnemonic.entropy(), metaId: metaId, accountId: accountId)

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportSeedRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: ethereumBased
            )

            let chaincodes = junctionResult?.chaincodes ?? []

            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = ethereumBased ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

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

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeystoreRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            let ethereumBased = request.cryptoType == .ethereumEcdsa

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .substrateEcdsa, .ethereumEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let metaId = UUID().uuidString
            let accountId = ethereumBased ? try publicKey.rawData().ethereumAddressFromPublicKey() :
                try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: metaAccount.metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: request.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            try self.saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }
}
