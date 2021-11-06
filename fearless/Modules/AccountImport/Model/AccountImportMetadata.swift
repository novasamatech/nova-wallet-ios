import Foundation

struct MetaAccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
}
