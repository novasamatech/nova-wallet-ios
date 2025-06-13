import Foundation
import SubstrateSdk

protocol CloudBackupFileModelConverting {
    func convertToPublicInfo(from wallets: Set<MetaAccountModel>) throws -> Set<CloudBackup.WalletPublicInfo>
    func convertFromPublicInfo(models: Set<CloudBackup.WalletPublicInfo>) throws -> Set<MetaAccountModel>
}

enum CloudBackupFileModelConvertingError: Error {
    case unexpectedLocalCryptoType(UInt8)
    case unexpectedLocalWalletType(MetaAccountModelType)
}

final class CloudBackupFileModelConverter {
    private func convertSubstrateCryptoTypeToLocal(_ cryptoType: CloudBackup.SubstrateCryptoType) -> UInt8 {
        switch cryptoType {
        case .sr25519:
            return MultiassetCryptoType.sr25519.rawValue
        case .ed25519:
            return MultiassetCryptoType.ed25519.rawValue
        case .ecdsa:
            return MultiassetCryptoType.substrateEcdsa.rawValue
        }
    }

    private func convertSubstrateCryptoTypeToBackup(_ cryptoType: UInt8) throws -> CloudBackup.SubstrateCryptoType {
        switch MultiassetCryptoType(rawValue: cryptoType) {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa:
            return .ecdsa
        case .ethereumEcdsa, .none:
            throw CloudBackupFileModelConvertingError.unexpectedLocalCryptoType(cryptoType)
        }
    }

    private func convertChainAccountCryptoTypeToBackup(
        _ cryptoType: UInt8
    ) throws -> CloudBackup.ChainAccountCryptoType {
        switch MultiassetCryptoType(rawValue: cryptoType) {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa:
            return .substrateEcdsa
        case .ethereumEcdsa:
            return .ethereumEcdsa
        case .none:
            throw CloudBackupFileModelConvertingError.unexpectedLocalCryptoType(cryptoType)
        }
    }

    private func convertChainAccountCryptoTypeToLocal(_ cryptoType: CloudBackup.ChainAccountCryptoType) -> UInt8 {
        switch cryptoType {
        case .sr25519:
            return MultiassetCryptoType.sr25519.rawValue
        case .ed25519:
            return MultiassetCryptoType.ed25519.rawValue
        case .substrateEcdsa:
            return MultiassetCryptoType.substrateEcdsa.rawValue
        case .ethereumEcdsa:
            return MultiassetCryptoType.ethereumEcdsa.rawValue
        }
    }

    private func convertWalletTypeToLocal(_ walletType: CloudBackup.WalletType) -> MetaAccountModelType {
        switch walletType {
        case .secrets:
            return .secrets
        case .watchOnly:
            return .watchOnly
        case .paritySigner:
            return .paritySigner
        case .ledger:
            return .ledger
        case .polkadotVault:
            return .polkadotVault
        case .polkadotVaultRoot:
            return .polkadotVaultRoot
        case .genericLedger:
            return .genericLedger
        }
    }

    private func convertWalletTypeToBackup(_ walletType: MetaAccountModelType) throws -> CloudBackup.WalletType {
        switch walletType {
        case .secrets:
            return .secrets
        case .watchOnly:
            return .watchOnly
        case .paritySigner:
            return .paritySigner
        case .ledger:
            return .ledger
        case .polkadotVault:
            return .polkadotVault
        case .polkadotVaultRoot:
            return .polkadotVaultRoot
        case .genericLedger:
            return .genericLedger
        case .proxied:
            throw CloudBackupFileModelConvertingError.unexpectedLocalWalletType(walletType)
        }
    }

    private func convertChainAccountToLocal(_ chainAccount: CloudBackup.ChainAccountInfo) throws -> ChainAccountModel {
        let accountId = try Data(hexString: chainAccount.accountId)
        let publicKey = try Data(hexString: chainAccount.publicKey)

        let cryptoType = convertChainAccountCryptoTypeToLocal(chainAccount.cryptoType)

        return ChainAccountModel(
            chainId: chainAccount.chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: nil
        )
    }

    private func convertChainAccountToBackup(_ chainAccount: ChainAccountModel) throws -> CloudBackup.ChainAccountInfo {
        let cryptoType = try convertChainAccountCryptoTypeToBackup(chainAccount.cryptoType)

        return CloudBackup.ChainAccountInfo(
            chainId: chainAccount.chainId,
            publicKey: chainAccount.publicKey.toHex(includePrefix: false),
            accountId: chainAccount.accountId.toHex(includePrefix: false),
            cryptoType: cryptoType
        )
    }
}

extension CloudBackupFileModelConverter: CloudBackupFileModelConverting {
    func convertToPublicInfo(from wallets: Set<MetaAccountModel>) throws -> Set<CloudBackup.WalletPublicInfo> {
        let publicInfoList = try wallets.map { localWallet in
            let substratePublicKey = localWallet.substratePublicKey?.toHex(includePrefix: false)
            let substrateAccountId = localWallet.substrateAccountId?.toHex(includePrefix: false)

            let ethereumAddress = localWallet.ethereumAddress?.toHex(includePrefix: false)
            let ethereumPublicKey = localWallet.ethereumPublicKey?.toHex(includePrefix: false)

            let cryptoType = try localWallet.substrateCryptoType.map { try convertSubstrateCryptoTypeToBackup($0) }
            let walletType = try convertWalletTypeToBackup(localWallet.type)

            let chainAccounts = try localWallet.chainAccounts.map { localChainAccount in
                try convertChainAccountToBackup(localChainAccount)
            }

            return CloudBackup.WalletPublicInfo(
                walletId: localWallet.metaId,
                substratePublicKey: substratePublicKey,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: cryptoType,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumPublicKey,
                name: localWallet.name,
                type: walletType,
                chainAccounts: Set(chainAccounts)
            )
        }

        return Set(publicInfoList)
    }

    func convertFromPublicInfo(models: Set<CloudBackup.WalletPublicInfo>) throws -> Set<MetaAccountModel> {
        let wallets = try models.map { publicInfo in
            let substrateAccountId = try publicInfo.substrateAccountId.map { try Data(hexString: $0) }
            let substratePublicKey = try publicInfo.substratePublicKey.map { try Data(hexString: $0) }

            let ethereumAddress = try publicInfo.ethereumAddress.map { try Data(hexString: $0) }
            let ethereumPublicKey = try publicInfo.ethereumPublicKey.map { try Data(hexString: $0) }

            let substrateCryptoType = publicInfo.substrateCryptoType.map { convertSubstrateCryptoTypeToLocal($0) }
            let type = convertWalletTypeToLocal(publicInfo.type)

            let chainAccounts = try publicInfo.chainAccounts.map { remoteChainAccount in
                try convertChainAccountToLocal(remoteChainAccount)
            }

            return MetaAccountModel(
                metaId: publicInfo.walletId,
                name: publicInfo.name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: substrateCryptoType,
                substratePublicKey: substratePublicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumPublicKey,
                chainAccounts: Set(chainAccounts),
                type: type
            )
        }

        return Set(wallets)
    }
}
