import Foundation

protocol CloudBackupValidating {
    func validate(
        publicData: CloudBackup.PublicData,
        matches privateData: CloudBackup.DecryptedFileModel.PrivateData
    ) -> Bool
}

final class ICloudBackupValidator {
    private func validateSecrets(
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) -> Bool {
        privateInfo.substrate?.keypair != nil ||
            privateInfo.ethereum?.keypair != nil ||
            privateInfo.chainAccounts.contains { $0.keypair != nil }
    }

    private func validateLedger(privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo) -> Bool {
        privateInfo.chainAccounts.contains { $0.derivationPath != nil }
    }

    private func validateGenericLedger(
        publicInfo: CloudBackup.WalletPublicInfo,
        privateInfo: CloudBackup.DecryptedFileModel.WalletPrivateInfo
    ) -> Bool {
        let hasEthereumAddress = publicInfo.ethereumAddress != nil
        let hasEthereumDerivationPath = privateInfo.ethereum?.derivationPath != nil

        // if ethereum part exists then it must be corresponding derivation path
        let isEthereumValid = hasEthereumAddress == hasEthereumDerivationPath

        let isSubstrateValid = privateInfo.substrate?.derivationPath != nil

        return isSubstrateValid && isEthereumValid
    }
}

extension ICloudBackupValidator: CloudBackupValidating {
    func validate(
        publicData: CloudBackup.PublicData,
        matches: CloudBackup.DecryptedFileModel.PrivateData
    ) -> Bool {
        let privateDataDict = matches.wallets.reduce(
            into: [MetaAccountModel.Id: CloudBackup.DecryptedFileModel.WalletPrivateInfo]()
        ) {
            $0[$1.walletId] = $1
        }

        return publicData.wallets.allSatisfy { wallet in
            switch wallet.type {
            case .secrets:
                guard let privateInfo = privateDataDict[wallet.walletId] else {
                    return false
                }

                return validateSecrets(privateInfo: privateInfo)
            case .ledger:
                guard let privateInfo = privateDataDict[wallet.walletId] else {
                    return false
                }

                return validateLedger(privateInfo: privateInfo)
            case .genericLedger:
                guard let privateInfo = privateDataDict[wallet.walletId] else {
                    return false
                }

                return validateGenericLedger(
                    publicInfo: wallet,
                    privateInfo: privateInfo
                )
            case .watchOnly, .paritySigner, .polkadotVault, .polkadotVaultRoot:
                return true
            }
        }
    }
}
