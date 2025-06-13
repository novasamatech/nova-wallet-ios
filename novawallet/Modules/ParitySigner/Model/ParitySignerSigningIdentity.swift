import Foundation

enum ParitySignerSigningIdentity {
    struct Regular {
        let accountId: AccountId
        let cryptoType: MultiassetCryptoType
    }

    struct DynamicDerivation {
        let rootKeyId: Data
        let crytoType: MultiassetCryptoType
        let derivationPath: String

        init(
            rootKeyId: Data,
            crytoType: MultiassetCryptoType,
            derivationPath: String = ""
        ) {
            self.rootKeyId = rootKeyId
            self.crytoType = crytoType
            self.derivationPath = derivationPath
        }
    }

    case regular(Regular)
    case dynamicDerivation(DynamicDerivation)
}
