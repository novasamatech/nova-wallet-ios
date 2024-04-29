import Foundation

struct MetaAccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
}
