import Foundation

extension CloudBackup {
    struct FileModel {
        struct PublicData {
            let modifiedAt: UInt64
            let wallets: [WalletPublicInfo]
        }

        struct WalletPublicInfo {
            let walletId: String
            let substratePublicKey: String?
            let substrateAccountId: String?
            let substrateCryptoType: CryptoType?
            let ethereumAddress: String?
            let ethereumPublicKey: String?
            let name: String
            let type: WalletType
            let chainAccounts: [ChainAccountInfo]
        }

        struct ChainAccountInfo {
            let chainId: String
            let publicKey: String
            let accountId: String
            let cryptoType: CryptoType?
        }

        struct PrivateData {
            let wallets: [WalletPrivateInfo]
        }

        struct WalletPrivateInfo {
            let walletId: String
            let entropy: String?
            let substrate: SubstrateSecrets?
            let ethereum: EthereumSecrets?
            let chainAccounts: ChainAccountSecrets?
            let additional: [String: String]
        }

        struct SubstrateSecrets {
            let seed: String?
            let keypair: KeypairSecrets
            let derivationPath: String?
        }

        struct EthereumSecrets {
            let keypair: KeypairSecrets
            let derivationPath: String?
        }

        struct ChainAccountSecrets {
            let accountId: String
            let entropy: String?
            let seed: String?
            let keypair: KeypairSecrets
        }

        struct KeypairSecrets {
            let publicKey: String
            let privateKey: String
            let nonce: String? // for SR25519
        }

        enum CryptoType: String {
            case sr25519 = "SR25519"
            case ed25519 = "ED25519"
            case ecdsa = "ECDSA"
        }

        enum WalletType: String {
            case secrets = "SECRETS"
            case watchOnly = "WATCH_ONLY"
            case paritySigner = "PARITY_SIGNER"
            case ledger = "LEDGER"
            case polkadotVault = "POLKADOT_VAULT"
        }

        let publicData: PublicData
        let privateDate: PrivateData
    }
}
