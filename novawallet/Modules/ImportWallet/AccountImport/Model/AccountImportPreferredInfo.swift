import Foundation

struct MetaAccountImportPreferredInfo {
    let username: String?
    let cryptoType: MultiassetCryptoType?
    let genesisHash: Data?
    let substrateDeriviationPath: String?
    let evmDeriviationPath: String?
    let source: SecretSource

    init(
        username: String?,
        cryptoType: MultiassetCryptoType?,
        genesisHash: Data?,
        substrateDeriviationPath: String?,
        evmDeriviationPath: String?,
        source: SecretSource
    ) {
        self.username = username
        self.cryptoType = cryptoType
        self.genesisHash = genesisHash
        self.substrateDeriviationPath = substrateDeriviationPath
        self.evmDeriviationPath = evmDeriviationPath
        self.source = source
    }
}
