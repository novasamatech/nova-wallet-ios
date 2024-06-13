import Foundation

struct ExportData {
    enum ChainType {
        case substrate(ExportChainData)
        case ethereum(ExportChainData)
    }

    let chains: [ChainType]
}

struct ExportChainData {
    let name: String
    let availableOptions: [SecretSource]
    let derivationPath: String?
    let cryptoType: MultiassetCryptoType
}
