import Foundation
import Keystore_iOS

protocol CloudBackupSecretsImporting {
    func importBackup(
        from model: CloudBackup.EncryptedFileModel,
        password: String,
        onlyWallets: Set<CloudBackup.WalletId>?
    ) throws -> Set<MetaAccountModel>

    func canImport(backup: CloudBackup.EncryptedFileModel, password: String) -> Bool
}

enum CloudBackupSecretsImportingError: Error {
    case decodingFailed(Error)
    case decryptionFailed(Error)
    case validationFailed
}

final class CloudBackupSecretsImporter {
    let keychain: KeystoreProtocol
    let walletConverter: CloudBackupFileModelConverting
    let cryptoManager: CloudBackupCryptoManagerProtocol
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

    private func decrypt(data: Data, password: String) throws -> Data {
        do {
            return try cryptoManager.decrypt(data: data, password: password)
        } catch {
            throw CloudBackupSecretsImportingError.decryptionFailed(error)
        }
    }

    private func decodePrivate(
        from backup: CloudBackup.EncryptedFileModel,
        password: String
    ) throws -> CloudBackup.DecryptedFileModel.PrivateData {
        do {
            let encryptedData = try Data(hexString: backup.privateData)

            let decryptedData = try decrypt(data: encryptedData, password: password)

            return try JSONDecoder().decode(
                CloudBackup.DecryptedFileModel.PrivateData.self,
                from: decryptedData
            )
        } catch {
            if let importError = error as? CloudBackupSecretsImportingError {
                throw importError
            } else {
                throw CloudBackupSecretsImportingError.decodingFailed(error)
            }
        }
    }

    private func saveEntropy(_ entropy: String, wallet: MetaAccountModel, accountId: AccountId?) throws {
        let entropyData = try Data(hexString: entropy)
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(entropyData, with: tag)
    }

    private func saveSeed(
        _ seed: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        let seedData = try Data(hexString: seed)
        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(seedData, with: tag)
    }

    private func savePrivateKey(
        _ secrets: CloudBackup.DecryptedFileModel.KeypairSecrets,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let privateKeyData = try Data(hexString: secrets.privateKey)

        if let nonceHex = secrets.nonce {
            let nonce = try Data(hexString: nonceHex)
            try keychain.saveKey(privateKeyData + nonce, with: tag)
        } else {
            try keychain.saveKey(privateKeyData, with: tag)
        }
    }

    private func saveDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        switch wallet.type {
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied, .watchOnly, .multisig:
            return try saveRegularDerivationPath(
                derivationPath,
                wallet: wallet,
                accountId: accountId,
                isEthereumBased: isEthereumBased
            )
        case .ledger, .genericLedger:
            return try saveLedgerDerivationPath(
                derivationPath,
                wallet: wallet,
                accountId: accountId,
                isEthereumBased: isEthereumBased
            )
        }
    }

    private func saveRegularDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        guard let derivationPathData = derivationPath.asSecretData(), !derivationPathData.isEmpty else {
            return
        }

        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)
        try keychain.saveKey(derivationPathData, with: tag)
    }

    private func saveLedgerDerivationPath(
        _ derivationPath: String,
        wallet: MetaAccountModel,
        accountId: AccountId?,
        isEthereumBased: Bool
    ) throws {
        guard !derivationPath.isEmpty else {
            return
        }

        let derivationPathData = try LedgerPathConverter().convertToChaincodesData(from: derivationPath)

        let tag = isEthereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)

        try keychain.saveKey(derivationPathData, with: tag)
    }

    private func importUniversalWalletSecrets(
        _ wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        if let entropyHex = privateInfo.entropy {
            try saveEntropy(entropyHex, wallet: wallet, accountId: nil)
        }

        if let substrate = privateInfo.substrate {
            if let derivationPath = substrate.derivationPath {
                try saveDerivationPath(derivationPath, wallet: wallet, accountId: nil, isEthereumBased: false)
            }

            if let seedHex = substrate.seed {
                try saveSeed(seedHex, wallet: wallet, accountId: nil, isEthereumBased: false)
            }

            if let keypair = substrate.keypair {
                try savePrivateKey(keypair, wallet: wallet, accountId: nil, isEthereumBased: false)
            }
        }

        if let ethereum = privateInfo.ethereum {
            if let derivationPath = ethereum.derivationPath {
                try saveDerivationPath(derivationPath, wallet: wallet, accountId: nil, isEthereumBased: true)
            }

            if let seedHex = ethereum.seed {
                try saveSeed(seedHex, wallet: wallet, accountId: nil, isEthereumBased: true)
            }

            if let keypair = ethereum.keypair {
                try savePrivateKey(keypair, wallet: wallet, accountId: nil, isEthereumBased: true)
            }
        }
    }

    private func importChainAccountsSecrets(
        _ wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        try privateInfo.chainAccounts.forEach { backupChainAccount in
            let accountId = try Data(hexString: backupChainAccount.accountId)

            if let entropy = backupChainAccount.entropy {
                try saveEntropy(entropy, wallet: wallet, accountId: accountId)
            }

            guard let chainAccount = wallet.chainAccounts.first(where: { $0.accountId == accountId }) else {
                return
            }

            if let seed = backupChainAccount.seed {
                try saveSeed(
                    seed,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }

            if let derivationPath = backupChainAccount.derivationPath {
                try saveDerivationPath(
                    derivationPath,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }

            if let keypair = backupChainAccount.keypair {
                try savePrivateKey(
                    keypair,
                    wallet: wallet,
                    accountId: accountId,
                    isEthereumBased: chainAccount.isEthereumBased
                )
            }
        }
    }

    private func importWallet(
        _ wallet: MetaAccountModel,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) throws {
        try importUniversalWalletSecrets(wallet, privateInfo: privateInfo)
        try importChainAccountsSecrets(wallet, privateInfo: privateInfo)
    }
}

extension CloudBackupSecretsImporter: CloudBackupSecretsImporting {
    func importBackup(
        from backup: CloudBackup.EncryptedFileModel,
        password: String,
        onlyWallets: Set<CloudBackup.WalletId>?
    ) throws -> Set<MetaAccountModel> {
        let privateData = try decodePrivate(from: backup, password: password)

        guard validator.validate(publicData: backup.publicData, matches: privateData) else {
            throw CloudBackupSecretsImportingError.validationFailed
        }

        let allWallets = try walletConverter.convertFromPublicInfo(models: backup.publicData.wallets)

        let wallets = if let onlyWallets = onlyWallets {
            allWallets.filter { onlyWallets.contains($0.metaId) }
        } else {
            allWallets
        }

        let initDataByWalletId = [String: CloudBackup.DecryptedFileModel.WalletPrivateInfo]()
        let privateDataByWalletId = privateData.wallets.reduce(into: initDataByWalletId) { accum, privateInfo in
            accum[privateInfo.walletId] = privateInfo
        }

        for wallet in wallets {
            if let privateInfo = privateDataByWalletId[wallet.metaId] {
                try importWallet(wallet, privateInfo: privateInfo)
            }
        }

        return wallets
    }

    func canImport(backup: CloudBackup.EncryptedFileModel, password: String) -> Bool {
        do {
            let privateData = try decodePrivate(from: backup, password: password)
            return validator.validate(publicData: backup.publicData, matches: privateData)
        } catch {
            return false
        }
    }
}
