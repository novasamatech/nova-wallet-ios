import Foundation

struct MetaAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let derivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct MetaAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct MetaAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportMnemonicRequest {
    let mnemonic: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportSeedRequest {
    let seed: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let cryptoType: MultiassetCryptoType
}
