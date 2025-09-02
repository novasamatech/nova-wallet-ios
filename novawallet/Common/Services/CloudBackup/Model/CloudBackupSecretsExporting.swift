import Foundation
import Keystore_iOS
import SubstrateSdk
import NovaCrypto

protocol CloudBackupSecretsExporting {
    func backup(
        wallets: Set<MetaAccountModel>,
        password: String,
        modifiedAt: UInt64
    ) throws -> CloudBackup.EncryptedFileModel
}

enum CloudBackupSecretsExporterError: Error {
    case unsupportedWallet(MetaAccountModelType)
    case invalidSecret(UInt8)
    case brokenSecrets(MetaAccountModel.Id)
    case validationFailed
}

final class CloudBackupSecretsExporter {
    let walletConverter: CloudBackupFileModelConverting
    let cryptoManager: CloudBackupCryptoManagerProtocol
    let keychain: KeystoreProtocol
    let validator: CloudBackupValidating

    init(
        walletConverter: CloudBackupFileModelConverting,
        cryptoManager: CloudBackupCryptoManagerProtocol,
        validator: CloudBackupValidating,
        keychain: KeystoreProtocol
    ) {
        self.walletConverter = walletConverter
        self.cryptoManager = cryptoManager
        self.validator = validator
        self.keychain = keychain
    }

    private func convertToBackup(
        secretKey: Data,
        publicKey: Data,
        cryptoType: UInt8
    ) throws -> CloudBackup.DecryptedFileModel.KeypairSecrets? {
        let publicKeyHex = publicKey.toHex()

        switch MultiassetCryptoType(rawValue: cryptoType) {
        case .sr25519:
            guard secretKey.count == CloudBackup.SecretsConstants.sr25519Size else {
                throw CloudBackupSecretsExporterError.invalidSecret(cryptoType)
            }

            let privateKeyHex = secretKey.prefix(CloudBackup.SecretsConstants.sr25519PrivateKeySize).toHex()

            let nonceHex = secretKey.suffix(CloudBackup.SecretsConstants.sr25519PrivateKeySize).toHex()

            return .init(publicKey: publicKeyHex, privateKey: privateKeyHex, nonce: nonceHex)
        case .ed25519, .substrateEcdsa, .ethereumEcdsa:
            let privateKeyHex = secretKey.toHex()
            return .init(publicKey: publicKeyHex, privateKey: privateKeyHex, nonce: nil)
        case .none:
            throw CloudBackupSecretsExporterError.invalidSecret(cryptoType)
        }
    }

    private func fetchEntropy(for wallet: MetaAccountModel, chainAccount: ChainAccountModel?) throws -> String? {
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: chainAccount?.accountId)
        let entropy = try keychain.loadIfKeyExists(tag)
        return entropy?.toHex()
    }

    private func fetchDerivationPath(
        for wallet: MetaAccountModel,
        chainAccount: ChainAccountModel?,
        isEthereumBased: Bool
    ) throws -> String? {
        switch wallet.type {
        case .secrets, .paritySigner, .polkadotVault, .proxied, .watchOnly, .multisig:
            return try fetchRegularDerivationPath(
                for: wallet,
                chainAccount: chainAccount,
                isEthereumBased: isEthereumBased
            )
        case .ledger, .genericLedger:
            return try fetchLedgerDerivationPath(
                for: wallet,
                chainAccount: chainAccount,
                isEthereumBased: isEthereumBased
            )
        }
    }

    private func fetchRegularDerivationPath(
        for wallet: MetaAccountModel,
        chainAccount: ChainAccountModel?,
        isEthereumBased: Bool
    ) throws -> String? {
        let tag = if isEthereumBased {
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: chainAccount?.accountId)
        } else {
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: chainAccount?.accountId)
        }

        guard let derivationPath = try keychain.loadIfKeyExists(tag) else {
            return nil
        }

        return String(data: derivationPath, encoding: .utf8)
    }

    private func fetchLedgerDerivationPath(
        for wallet: MetaAccountModel,
        chainAccount: ChainAccountModel?,
        isEthereumBased: Bool
    ) throws -> String? {
        let tag = if isEthereumBased {
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: chainAccount?.accountId)
        } else {
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: chainAccount?.accountId)
        }

        guard let derivationPath = try keychain.loadIfKeyExists(tag) else {
            return nil
        }

        return try LedgerPathConverter().convertFromChaincodesData(from: derivationPath)
    }

    private func fetchSeed(
        for wallet: MetaAccountModel,
        chainAccountModel: ChainAccountModel?,
        isEthereumBased: Bool
    ) throws -> String? {
        let tag = if isEthereumBased {
            KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId, accountId: chainAccountModel?.accountId)
        } else {
            KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: chainAccountModel?.accountId)
        }

        let seed = try keychain.loadIfKeyExists(tag)

        return seed?.toHex()
    }

    private func fetchPrivateKey(
        for wallet: MetaAccountModel,
        chainAccountModel: ChainAccountModel?,
        isEthereumBased: Bool
    ) throws -> CloudBackup.DecryptedFileModel.KeypairSecrets? {
        let tag = if isEthereumBased {
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: chainAccountModel?.accountId)
        } else {
            KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: chainAccountModel?.accountId)
        }

        guard let privateKey = try keychain.loadIfKeyExists(tag) else {
            return nil
        }

        if let chainAccountModel {
            return try convertToBackup(
                secretKey: privateKey,
                publicKey: chainAccountModel.publicKey,
                cryptoType: chainAccountModel.cryptoType
            )
        } else if isEthereumBased, let publicKey = wallet.ethereumPublicKey {
            return try convertToBackup(
                secretKey: privateKey,
                publicKey: publicKey,
                cryptoType: MultiassetCryptoType.ethereumEcdsa.rawValue
            )
        } else if
            !isEthereumBased,
            let publicKey = wallet.substratePublicKey,
            let cryptoType = wallet.substrateCryptoType {
            return try convertToBackup(
                secretKey: privateKey,
                publicKey: publicKey,
                cryptoType: cryptoType
            )
        } else {
            throw CloudBackupSecretsExporterError.brokenSecrets(wallet.metaId)
        }
    }

    private func fetchUniversalSubstrateSecrets(
        for wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.SubstrateSecrets? {
        guard
            let keypairSecrets = try fetchPrivateKey(
                for: wallet,
                chainAccountModel: nil,
                isEthereumBased: false
            ) else {
            return nil
        }

        let seed = try fetchSeed(for: wallet, chainAccountModel: nil, isEthereumBased: false)
        let derivationPath = try fetchDerivationPath(for: wallet, chainAccount: nil, isEthereumBased: false)

        return .init(seed: seed, keypair: keypairSecrets, derivationPath: derivationPath)
    }

    private func fetchUniversalEthereumSecrets(
        for wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.EthereumSecrets? {
        guard
            let keypairSecrets = try fetchPrivateKey(
                for: wallet,
                chainAccountModel: nil,
                isEthereumBased: true
            ) else {
            return nil
        }

        let seed = try fetchSeed(for: wallet, chainAccountModel: nil, isEthereumBased: true)
        let derivationPath = try fetchDerivationPath(for: wallet, chainAccount: nil, isEthereumBased: true)

        return .init(seed: seed, keypair: keypairSecrets, derivationPath: derivationPath)
    }

    private func createChainAccountSecrets(
        from wallet: MetaAccountModel
    ) throws -> Set<CloudBackup.DecryptedFileModel.ChainAccountSecrets> {
        let chainAccountSecrets = try wallet.chainAccounts.map { chainAccount in
            let accountId = chainAccount.accountId.toHex()
            let entropyData = try fetchEntropy(for: wallet, chainAccount: chainAccount)
            let seed = try fetchSeed(
                for: wallet,
                chainAccountModel: chainAccount,
                isEthereumBased: chainAccount.isEthereumBased
            )

            let keypair = try fetchPrivateKey(
                for: wallet,
                chainAccountModel: chainAccount,
                isEthereumBased: chainAccount.isEthereumBased
            )

            let derivationPath = try fetchDerivationPath(
                for: wallet,
                chainAccount: chainAccount,
                isEthereumBased: chainAccount.isEthereumBased
            )

            return CloudBackup.DecryptedFileModel.ChainAccountSecrets(
                accountId: accountId,
                entropy: entropyData,
                seed: seed,
                keypair: keypair,
                derivationPath: derivationPath
            )
        }

        return Set(chainAccountSecrets)
    }

    private func createPrivateInfoFromSecretsWalletType(
        _ wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.WalletPrivateInfo {
        let entropy = try fetchEntropy(for: wallet, chainAccount: nil)
        let substrate = try fetchUniversalSubstrateSecrets(for: wallet)
        let ethereum = try fetchUniversalEthereumSecrets(for: wallet)
        let chainAccounts = try createChainAccountSecrets(from: wallet)

        return .init(
            walletId: wallet.metaId,
            entropy: entropy,
            substrate: substrate,
            ethereum: ethereum,
            chainAccounts: chainAccounts
        )
    }

    private func createPrivateInfoFromLedgerWalletType(
        _ wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.WalletPrivateInfo {
        let chainAccounts = try createChainAccountSecrets(from: wallet)

        return .init(
            walletId: wallet.metaId,
            entropy: nil,
            substrate: nil,
            ethereum: nil,
            chainAccounts: chainAccounts
        )
    }

    private func createPrivateInfoFromGenericWalletType(
        _ wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.WalletPrivateInfo {
        let substrateDerivationPath = try fetchDerivationPath(
            for: wallet,
            chainAccount: nil,
            isEthereumBased: false
        )

        let substrateSecrets = CloudBackup.DecryptedFileModel.SubstrateSecrets(
            seed: nil,
            keypair: nil,
            derivationPath: substrateDerivationPath
        )

        let ethereumSecrets: CloudBackup.DecryptedFileModel.EthereumSecrets?

        if wallet.ethereumAddress != nil {
            let evmDerivationPath = try fetchDerivationPath(
                for: wallet,
                chainAccount: nil,
                isEthereumBased: true
            )

            ethereumSecrets = CloudBackup.DecryptedFileModel.EthereumSecrets(
                seed: nil,
                keypair: nil,
                derivationPath: evmDerivationPath
            )
        } else {
            ethereumSecrets = nil
        }

        return .init(
            walletId: wallet.metaId,
            entropy: nil,
            substrate: substrateSecrets,
            ethereum: ethereumSecrets,
            chainAccounts: []
        )
    }

    private func createPrivateInfo(
        from wallet: MetaAccountModel
    ) throws -> CloudBackup.DecryptedFileModel.WalletPrivateInfo? {
        switch wallet.type {
        case .secrets:
            return try createPrivateInfoFromSecretsWalletType(wallet)
        case .genericLedger:
            return try createPrivateInfoFromGenericWalletType(wallet)
        case .ledger:
            return try createPrivateInfoFromLedgerWalletType(wallet)
        case .watchOnly, .polkadotVault, .paritySigner:
            return nil
        case .proxied, .multisig:
            // add backup for generic ledger
            throw CloudBackupSecretsExporterError.unsupportedWallet(wallet.type)
        }
    }
}

extension CloudBackupSecretsExporter: CloudBackupSecretsExporting {
    func backup(
        wallets: Set<MetaAccountModel>,
        password: String,
        modifiedAt: UInt64
    ) throws -> CloudBackup.EncryptedFileModel {
        let publicWalletsData = try walletConverter.convertToPublicInfo(from: wallets)
        let privateInfoList = try wallets.compactMap { wallet in
            try createPrivateInfo(from: wallet)
        }

        let publicData = CloudBackup.PublicData(modifiedAt: modifiedAt, wallets: publicWalletsData)
        let privateInfo = CloudBackup.DecryptedFileModel.PrivateData(wallets: Set(privateInfoList))

        guard validator.validate(publicData: publicData, matches: privateInfo) else {
            throw CloudBackupSecretsExporterError.validationFailed
        }

        let encodedPrivateInfo = try JSONEncoder().encode(privateInfo)
        let encryptedInfo = try cryptoManager.encrypt(data: encodedPrivateInfo, password: password)

        return .init(publicData: publicData, privateData: encryptedInfo.toHex())
    }
}
