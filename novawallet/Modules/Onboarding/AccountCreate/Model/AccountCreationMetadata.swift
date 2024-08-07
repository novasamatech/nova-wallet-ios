import Foundation

struct MetaAccountAvailableCryptoTypes {
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
}

struct MetaAccountCreationMetadata {
    let mnemonic: [String]
}
