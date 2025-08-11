import Foundation

struct MetaAccountImportMetadata {
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
    let defaultSubstrateDerivationPath: String?
    let defaultEthereumDerivationPath: String?
}
