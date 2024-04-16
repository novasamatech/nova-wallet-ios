import Foundation
import SoraKeystore

protocol CloudBackupSecretsImporting {
    func importBackup(
        from model: CloudBackup.EncryptedFileModel,
        password: String,
        onlyWallets: Set<CloudBackup.WalletId>?
    ) throws -> Set<MetaAccountModel>

    func canImport(backup: CloudBackup.EncryptedFileModel, password: String) -> Bool
}

final class CloudBackupSecretsImporter {
    let keychain: Keychain
    let cryptoManager: CloudBackupCryptoManagerProtocol

    init(keychain: Keychain, cryptoManager: CloudBackupCryptoManagerProtocol) {
        self.keychain = keychain
        self.cryptoManager = cryptoManager
    }

    private func decodePrivate(
        from backup: CloudBackup.EncryptedFileModel,
        password: String
    ) throws -> CloudBackup.DecryptedFileModel.PrivateData {
        let encryptedData = try Data(hexString: backup.privateData)

        let decryptedData = try cryptoManager.decrypt(data: encryptedData, password: password)

        let decodedData = try JSONDecoder().decode(
            CloudBackup.DecryptedFileModel.PrivateData.self,
            from: decryptedData
        )

        // TODO: Validate

        return decodedData
    }
}

extension CloudBackupSecretsImporter: CloudBackupSecretsImporting {
    func importBackup(
        from _: CloudBackup.EncryptedFileModel,
        password _: String,
        onlyWallets _: Set<CloudBackup.WalletId>?
    ) throws -> Set<MetaAccountModel> {
        Set()
    }

    func canImport(backup: CloudBackup.EncryptedFileModel, password: String) -> Bool {
        do {
            _ = try decodePrivate(from: backup, password: password)

            return true
        } catch {
            return false
        }
    }
}
