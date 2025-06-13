import Foundation

extension CloudBackup {
    typealias WalletId = String

    struct PublicData: Codable, Equatable {
        let modifiedAt: UInt64
        let wallets: Set<WalletPublicInfo>
    }

    struct WalletPublicInfo: Codable, Equatable, Hashable {
        let walletId: WalletId
        let substratePublicKey: String?
        let substrateAccountId: String?
        let substrateCryptoType: SubstrateCryptoType?
        let ethereumAddress: String?
        let ethereumPublicKey: String?
        let name: String
        let type: WalletType
        let chainAccounts: Set<ChainAccountInfo>
    }

    struct ChainAccountInfo: Codable, Equatable, Hashable {
        let chainId: String
        let publicKey: String
        let accountId: String
        let cryptoType: ChainAccountCryptoType
    }

    enum SubstrateCryptoType: String, Codable, Equatable {
        case sr25519 = "SR25519"
        case ed25519 = "ED25519"
        case ecdsa = "ECDSA"
    }

    enum ChainAccountCryptoType: String, Codable, Equatable {
        case sr25519 = "SR25519"
        case ed25519 = "ED25519"
        case substrateEcdsa = "SubstrateECDSA"
        case ethereumEcdsa = "EthereumECDSA"
    }

    enum WalletType: String, Codable, Equatable {
        case secrets = "SECRETS"
        case watchOnly = "WATCH_ONLY"
        case paritySigner = "PARITY_SIGNER"
        case ledger = "LEDGER"
        case polkadotVault = "POLKADOT_VAULT"
        case genericLedger = "LEDGER_GENERIC"
        case polkadotVaultRoot = "POLKADOT_VAULT_ROOT"
    }

    struct DecryptedFileModel: Equatable {
        struct PrivateData: Codable, Equatable {
            let wallets: Set<WalletPrivateInfo>
        }

        struct WalletPrivateInfo: Codable, Equatable, Hashable {
            let walletId: CloudBackup.WalletId
            let entropy: String?
            let substrate: SubstrateSecrets?
            let ethereum: EthereumSecrets?
            let chainAccounts: Set<ChainAccountSecrets>
        }

        struct SubstrateSecrets: Codable, Equatable, Hashable {
            let seed: String?
            let keypair: KeypairSecrets?
            let derivationPath: String?
        }

        struct EthereumSecrets: Codable, Equatable, Hashable {
            let seed: String?
            let keypair: KeypairSecrets?
            let derivationPath: String?
        }

        struct ChainAccountSecrets: Codable, Equatable, Hashable {
            let accountId: String
            let entropy: String?
            let seed: String?
            let keypair: KeypairSecrets?
            let derivationPath: String?
        }

        struct KeypairSecrets: Codable, Equatable, Hashable {
            let publicKey: String
            let privateKey: String
            let nonce: String? // for SR25519
        }

        let publicData: CloudBackup.PublicData
        let privateDate: PrivateData
    }

    struct EncryptedFileModel: Codable, Equatable {
        let publicData: CloudBackup.PublicData
        let privateData: String
    }
}
