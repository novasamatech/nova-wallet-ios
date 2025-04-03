import Foundation
import NovaCrypto

struct MetaAccountCreationRequest {
    let username: String
    let derivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountCreationRequest {
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}
